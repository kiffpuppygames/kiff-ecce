
const std = @import("std");

pub const Entity = u64;
pub const ComponentReferences = std.AutoArrayHashMap(u8, u64);

pub fn create_component(data_type: type) type
{
    const Component = comptime struct 
    { 
        id: u64, 
        entity: Entity,         
        data: data_type,
    };

    return Component;
}

pub fn create_cecs(component_register: type) type
{
    const CECS = struct 
    {
        const Self = @This();
        var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        entities: std.AutoArrayHashMap(u64, ComponentReferences),
        components: std.A component_register,

        pub fn new() Self 
        {
            const entities = std.AutoArrayHashMap(u64, ComponentReferences).init(allocator.allocator());
            return Self 
            { 
                .entities = entities, 
                .components = component_register.new(allocator.allocator()),
                 
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
            
            self.components.deinit();            
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
    const PlayerData = comptime struct { id: i32, name: []const u8 };
    const PlayerComponent = comptime create_component(PlayerData);

    const entity: Entity = 1;
    const player_1 = PlayerComponent { .id = 1, .entity = entity, .data = PlayerData { .id = 42, .name = "Guy" } };

    try std.testing.expectEqual(entity, player_1.entity);
    try std.testing.expectEqual(42, player_1.data.id);    
    try std.testing.expectEqual("Guy", player_1.data.name);  
}

test "init cecs" 
{
    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();

    const PlayerData = comptime struct { id: i32, name: []const u8 };
    const HealthData = comptime struct { value: i32 };
    
    const Player = comptime create_component(PlayerData);
    const Health = comptime create_component(HealthData);

    const ComponentType = enum(u8) { Player = 0, Health = 1 };    
    const component_types = [_]type{ Player, Health };    
    const ComponentRegistry = comptime create_registry(&component_types);
    const CECS = comptime create_cecs(ComponentRegistry);

    var cecs = CECS.new();    
    defer cecs.deinit();

    const entity: Entity = 1;
    const player_component = Player { .id = 1, .entity = entity, .data = PlayerData { .id = 42, .name = "Guy" } };
    const health_component = Health { .id = 2, .entity = entity, .data = HealthData { .value = 100 } };

    try cecs.entities.put(entity, ComponentReferences.init(alloc.allocator()));

    var entity_components: *ComponentReferences = cecs.entities.getPtr(entity).?;
    try entity_components.put(@intFromEnum(ComponentType.Player), player_component.id);
    try entity_components.put(@intFromEnum(ComponentType.Health), health_component.id);

    try cecs.components.Player.put(player_component.id, player_component);
    try cecs.components.health_components.put(health_component.id, health_component);

    const entity_info: ComponentReferences = cecs.entities.get(entity).?;
    
    try std.testing.expectEqual(2, entity_info.count());
    try std.testing.expectEqual(player_component.id, entity_info.get(@intFromEnum(ComponentType.Player)).?);
    try std.testing.expectEqual(health_component.id, entity_info.get(@intFromEnum(ComponentType.Health)).?);
    try std.testing.expectEqual(42, cecs.component_registry.player_components.get(player_component.id).?.data.id);
    try std.testing.expectEqual("Guy", cecs.component_registry.player_components.get(player_component.id).?.data.name);
    
    try std.testing.expect(true);
}