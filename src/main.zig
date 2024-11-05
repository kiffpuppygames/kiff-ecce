
const std = @import("std");

pub const Entity = u64;
pub const ComponentReferences = std.AutoArrayHashMap(u64, u64);

pub const ComponentInfo = struct 
{
    component_type: type,
    component_type_id: u64 = undefined,
};

fn to_lower_case(input: []const u8) ![:0]const u8 
{
    const input_len = input.len;

    var buffer: [input_len:0]u8 = undefined;

    for (input, 0..) |c, i| 
    {
        buffer[i] = std.ascii.toLower(c);
    }
    
    return &buffer;
}

pub fn create_component(data_type: type, collection_handle: [:0]const u8) type
{
    const Component = comptime struct 
    { 
        const Self = @This();
        const handle: [:0]const u8 = collection_handle;
        const t_id: u64 = hash_type_name_64(@typeName(data_type));

        id: u64, 
        entity: Entity,         
        data: data_type,

        pub fn new() Self 
        {
            return Self { .id = 0, .entity = 0, .data = undefined };
        }
    };

    return Component;
}

pub fn create_component_register(component_infos: []const ComponentInfo) type
{
    const num_components = component_infos.len;
    var struct_fields: [component_infos.len * 2]std.builtin.Type.StructField = undefined;
    inline for (component_infos, 0..) |component_info, i| 
    {
        struct_fields[i] = std.builtin.Type.StructField {
            .name = component_info.component_type.handle,
            .type = std.AutoArrayHashMap(u64, comptime component_info.component_type),
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(component_info.component_type),
        };
    }

    inline for (component_infos, 0..) |component_info, i| 
    {
        struct_fields[num_components + i] = std.builtin.Type.StructField {
            .name = component_info.component_type.handle ++ "_next_id",
            .type = u64,
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(u64),
        };
    }

    const Entries: type = @Type(.{            
        .@"struct" = .{
            .layout = .auto,
            .fields = &struct_fields,
            .is_tuple = false,
            .decls = &[_]std.builtin.Type.Declaration{}
        },
    });

    const ComponentRegister = struct 
    {
        const Self = @This();

        entries: Entries,
        const infos= component_infos;

        pub fn new(allocator: *const std.mem.Allocator) Self 
        {
            var entries: Entries = undefined;

            inline for (Self.infos) |component_info| 
            {
                @field(entries,  try to_lower_case(component_info.component_type.handle)) = std.AutoArrayHashMap(u64, component_info.component_type).init(allocator.*);
            }

            return Self 
            {                
                .entries = entries,
            };
        }

        pub fn deinit(self: *Self) void 
        {
            inline for (infos) |component_info| 
            {
                @field(self.entries, component_info.runtime_name).deinit();
            }
        }
    };

    return ComponentRegister;
}

pub fn create_ecce(component_types: []const type) type
{
    const component_infos = comptime generate_component_infos(component_types);

    const ecce = struct 
    {
        const Self = @This();
        const ComponentRegister = create_component_register(&component_infos);
        var allocator: *const std.mem.Allocator = undefined;

        entities: std.AutoArrayHashMap(u64, ComponentReferences),
        components: ComponentRegister,

        pub fn new(alloc: *const std.mem.Allocator) Self 
        {
            allocator = alloc;
            const entities = std.AutoArrayHashMap(u64, ComponentReferences).init(allocator.*);
            const component_register = ComponentRegister.new(allocator);

            return Self 
            { 
                .entities = entities, 
                .components = component_register,
            };
        }

        pub fn deinit(self: *Self) void 
        {
            for (0..self.entities.count()) |_| 
            {
                var kv = self.entities.pop();
                kv.value.deinit();
            }
            self.entities.deinit();   
        }

        pub fn add_entity(self: *Self) !Entity 
        {
            const entity: Entity = self.get_next_entity_id();
            try self.entities.put(entity, ComponentReferences.init(allocator.*));            
            return entity;
        }

        inline fn get_next_entity_id(self: *Self) Entity 
        {
            return self.entities.count() + 1;
        }  

        pub fn add_component(self: *Self, entity: Entity, component: anytype) !void 
        {
            const component_type = @TypeOf(component);
            
            try @field(self.components.entries, component_type.handle).put(component.id, component);
            try self.entities.getPtr(entity).?.put(component_type.t_id, component.id);
        }

        pub fn get_component_by_id(self: *Self, component_type: type, component_id: u64) !component_type 
        {
            return @field(self.components.entries, component_type.handle).get(component_id).?;
        }

        pub fn get_component_by_entity(self: *Self, entity: Entity, component_type: type) !component_type 
        {
            const component_id = self.entities.get(entity).?.get(component_type.t_id);
            return self.get_component_by_id(component_type, component_id.?);
        }
    };

    return ecce;
}

fn generate_component_infos(component_types: []const type) [component_types.len]ComponentInfo
{
    var component_infos: [component_types.len]ComponentInfo = undefined;
    inline for (component_types, 0..) |component_type, i| 
    {
        component_infos[i] = ComponentInfo 
        {
            .component_type = component_type,
            .component_type_id = i,
        };
    }

    return component_infos;
}

fn hash_type_name_64(type_name: []const u8) u64 {
    var hash: u64 = 5381;
    for (type_name) |c| {
        const mul_result = @mulWithOverflow(hash, 33);
        const add_result = @addWithOverflow(mul_result[0], @as(u64, c));
        hash = add_result[0];
    }
    return hash;
}

test "init ecce" 
{
    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();

    const PlayerData = comptime struct { id: i32, name: []const u8 };
    const HealthData = comptime struct { value: i32 };
    
    const Player = comptime create_component(PlayerData, "player_components");
    const Health = comptime create_component(HealthData, "health_components");

    const component_types = [_]type {
        Player,
        Health,
    };

    const ECCE = comptime create_ecce(&component_types);

    var ecce = ECCE.new(&alloc.allocator());    
    defer ecce.deinit();

    const entity1: Entity = try ecce.add_entity();
    {
        const player1 = Player { .id = ecce.components.entries.player_components.values().len, .entity = entity1, .data = PlayerData { .id = 42, .name = "Guy" } };
        const health1 = Health { .id = ecce.components.entries.health_components.values().len, .entity = entity1, .data = HealthData { .value = 100 } };
        try ecce.add_component(entity1, player1);
        try ecce.add_component(entity1, health1);

        try std.testing.expectEqual(2, ecce.entities.get(entity1).?.values().len);
        try std.testing.expectEqual(player1.id, ecce.entities.get(entity1).?.get(Player.t_id).?);

        const stored_player = ecce.components.entries.player_components.get(player1.id).?;
        try std.testing.expectEqual(player1.data.name, stored_player.data.name);
        const stored_health = try ecce.get_component_by_id(Health, health1.id);
        try std.testing.expectEqual(health1.data.value, stored_health.data.value);
    }
    
    const entity2: Entity = try ecce.add_entity();
    {
        
        const player2 = Player { .id = ecce.components.entries.player_components.values().len, .entity = entity2, .data = PlayerData { .id = 42, .name = "Guy" } };
        const health2 = Health { .id = ecce.components.entries.health_components.values().len, .entity = entity2, .data = HealthData { .value = 150 } };
        try ecce.add_component(entity2, player2);
        try ecce.add_component(entity2, health2);

        try std.testing.expectEqual(2, ecce.entities.get(entity2).?.values().len);
        try std.testing.expectEqual(player2.id, ecce.entities.get(entity2).?.get(Player.t_id).?);
        
        const stored_player = ecce.components.entries.player_components.get(player2.id).?;
        try std.testing.expectEqual(player2.data.name, stored_player.data.name);
        const stored_health = try ecce.get_component_by_id(Health, health2.id);
        try std.testing.expectEqual(health2.data.value, stored_health.data.value);
    }

    try std.testing.expectEqual(ecce.entities.values().len, 2);
    try std.testing.expectEqual(ecce.components.entries.player_components.values().len, 2);
    try std.testing.expectEqual(ecce.components.entries.health_components.values().len, 2);
    
    try std.testing.expect(true);
}

pub fn main() !void {}