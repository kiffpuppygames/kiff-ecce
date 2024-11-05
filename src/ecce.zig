const std = @import("std");

const components = @import("components.zig");

pub const Entity = u64;

pub fn create_ecce(component_types: []const type) type
{
    const component_infos = comptime components.generate_component_infos(component_types);

    const ecce = struct 
    {
        const Self = @This();
        const ComponentRegister = components.create_component_register(&component_infos);
        var allocator: *const std.mem.Allocator = undefined;

        entities: std.AutoArrayHashMap(u64, components.ComponentReferences),
        components: ComponentRegister,

        pub fn new(alloc: *const std.mem.Allocator) Self 
        {
            allocator = alloc;
            const entities = std.AutoArrayHashMap(u64, components.ComponentReferences).init(allocator.*);
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
            try self.entities.put(entity, components.ComponentReferences.init(allocator.*));            
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