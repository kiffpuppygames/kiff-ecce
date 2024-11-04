
const std = @import("std");
const RndGen = std.Random.DefaultPrng;

pub const Entity = u64;
pub const ComponentReferences = std.AutoArrayHashMap(u8, u64);

pub const ComponentInfo = struct 
{
    component_type: type,
    component_type_id: u8 = undefined,
};

fn to_lowerCase_and_append_suffix(input: []const u8) ![:0]const u8 
{
    const input_len = input.len;

    var buffer: [input_len:0]u8 = undefined;

    // Convert input to lowercase
    for (input, 0..) |c, i| {
        buffer[i] = std.ascii.toLower(c);
    }

    // Add zero-length sentinel
    //buffer[total_len - 1] = 0;
    return &buffer;
}

pub fn create_component(data_type: type, collection_handle: [:0]const u8, type_id: u8) type
{
    const Component = comptime struct 
    { 
        const Self = @This();
        const handle: [:0]const u8 = collection_handle;
        const t_id: u8 = type_id;

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

pub fn create_component_register_entry(component_type: type) type
{
    const ComponentRegisterEntry = struct 
    {
        const Self = @This();

        components: std.AutoArrayHashMap(u64, component_type),

        pub fn new(allocator: std.mem.Allocator) Self 
        {
            return Self { .components = std.AutoArrayHashMap(u64, component_type).init(allocator) };
        }

        pub fn deinit(self: *Self) void 
        {
            self.components.deinit();
        }
    };

    return ComponentRegisterEntry;
}

pub fn create_component_register(component_infos: []const ComponentInfo) type
{
    var struct_fields: [component_infos.len]std.builtin.Type.StructField = undefined;
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

        pub fn new() Self 
        {
            var entries: Entries = undefined;

            inline for (Self.infos) |component_info| 
            {
                @field(entries,  try to_lowerCase_and_append_suffix(component_info.component_type.handle)) = undefined;
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

pub fn create_cecs(component_types: []const type) type
{
    const component_infos = comptime generate_component_infos(component_types);

    const CECS = struct 
    {
        const Self = @This();
        const ComponentRegister = create_component_register(&component_infos);

        entities: std.AutoArrayHashMap(u64, ComponentReferences),
        components: ComponentRegister,

        pub fn new(allocator: std.mem.Allocator) Self 
        {
            const entities = std.AutoArrayHashMap(u64, ComponentReferences).init(allocator);
            const component_register = ComponentRegister.new();

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

        pub fn add_entity(self: *Self, entity: Entity) void 
        {
            self.entities.put(entity, std.ArrayList(u64).init(self.allocator));
        }

        pub fn add_component(self: *Self, entity: Entity, component: anytype) void 
        {
            const component_type = @TypeOf(component);
            self.entities.get(entity).append(component_type, component.id);
            self.component_registry.get(component_type).put(component.id, component);
        }      
    };

    return CECS;
}

pub fn create_registry(component_types: []const type) type
{
    const ComponentRegistry = struct 
    {
        const Self = @This();

        comptime 
        {
            for (component_types) |component_type| 
            {
                @field(Self, @typeName(component_type)) = std.AutoArrayHashMap(u64, component_type); 
            }
        }
        
        pub fn new(allocator: std.mem.Allocator) Self 
        {
            return Self 
            {
                comptime 
                {
                    for (component_types) |component_type| 
                    {
                        @field(Self, @typeName(component_type)) = std.AutoArrayHashMap(u64, component_type).init(allocator); 
                    }
                }
            };
        }

        pub fn deinit(self: *Self) void 
        {
            comptime 
            {
                for (component_types) |component_type| 
                {
                    @field(self, @typeName(component_type)) = std.AutoArrayHashMap(u64, component_type); 
                }
            }
        }
    };

    return ComponentRegistry;
}

test "create component" 
{
    // const PlayerData = comptime struct { id: i32, name: []const u8 };
    // const PlayerComponent = comptime create_component(PlayerData);

    // const entity: Entity = 1;
    // const player_1 = PlayerComponent { .id = 1, .entity = entity, .data = PlayerData { .id = 42, .name = "Guy" } };

    // try std.testing.expectEqual(entity, player_1.entity);
    // try std.testing.expectEqual(42, player_1.data.id);    
    // try std.testing.expectEqual("Guy", player_1.data.name);  
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

const ComponentDescriptor = struct 
{
    component_type: type,
    collection_name: []const u8,
};

test "init cecs" 
{
    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();

    const PlayerData = comptime struct { id: i32, name: []const u8 };
    const HealthData = comptime struct { value: i32 };
    
    const Player = comptime create_component(PlayerData, "player_components", 0);
    const Health = comptime create_component(HealthData, "health_components", 1);

    const component_types = [_]type {
        Player,
        Health,
    };

    const CECS = comptime create_cecs(&component_types);

    var cecs = CECS.new(alloc.allocator());    
    defer cecs.deinit();

    const entity: Entity = 1;
    const player_component = Player { .id = 1, .entity = entity, .data = PlayerData { .id = 42, .name = "Guy" } };
    
    //const health_component = Health { .id = 2, .entity = entity, .data = HealthData { .value = 100 } };

    try cecs.entities.put(entity, ComponentReferences.init(alloc.allocator()));
    try cecs.entities.getPtr(entity).?.put(Player.t_id, player_component.id);

    cecs.components.entries.player_components = std.AutoArrayHashMap(u64, Player).init(alloc.allocator());
    try cecs.components.entries.player_components.put(player_component.id, player_component);

    try std.testing.expectEqual(cecs.components.entries.player_components.values().len, 1);

    //try cecs.components.Player.put(player_component.id, player_component);
    //try cecs.components.health_components.put(health_component.id, health_component);

    //const entity_info: ComponentReferences = cecs.entities.get(entity).?;
    //_ = entity_info; // autofix
    
    //try std.testing.expectEqual(2, entity_info.count());
    // try std.testing.expectEqual(player_component.id, entity_info.get(@intFromEnum(ComponentType.Player)).?);
    // try std.testing.expectEqual(health_component.id, entity_info.get(@intFromEnum(ComponentType.Health)).?);
    // try std.testing.expectEqual(42, cecs.component_registry.player_components.get(player_component.id).?.data.id);
    // try std.testing.expectEqual("Guy", cecs.component_registry.player_components.get(player_component.id).?.data.name);
    
    try std.testing.expect(true);
}

pub fn main() !void {}