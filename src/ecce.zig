const std = @import("std");

const components = @import("components.zig");
const commands = @import("commands.zig");

pub const Entity = u64;

pub fn create_ecce(component_types: []const type, command_types: []const type) type
{
    const component_infos = comptime components.generate_component_infos(component_types);

    const ecce = struct 
    {
        const Self = @This();
        const ComponentRegister = components.create_component_register(&component_infos);
        const CommandRegister = commands.create_command_register(command_types);
                        
        var allocator: *const std.mem.Allocator = undefined;
        var next_component_id: u64 = 0;
        var next_command_id: u64 = 0;
        var next_entity: Entity = 0;

        entities: std.AutoArrayHashMap(u64, components.ComponentReferences),
        components: ComponentRegister,
        commands: CommandRegister,

        pub fn new(alloc: *const std.mem.Allocator) Self 
        {
            allocator = alloc;
            const entities = std.AutoArrayHashMap(u64, components.ComponentReferences).init(allocator.*);
            const component_register = ComponentRegister.new(allocator);
            const command_register = CommandRegister.new(allocator);

            return Self 
            { 
                .entities = entities, 
                .components = component_register,
                .commands = command_register,
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
            _ = self; // autofix
            const entity = next_entity;
            next_entity += 1;
            return entity;
        }

        pub fn get_next_component_id(self: *Self) u64 
        {
            _ = self; // autofix
            const id = next_component_id;
            next_component_id += 1;
            return id;
        }

        pub fn get_next_command_id(self: *Self) u64 
        {
            _ = self; // autofix
            const id = next_command_id;
            next_command_id += 1;
            return id;
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

        pub fn dispatch_command(self: *Self, command: anytype) !void 
        {
            const command_type = @TypeOf(command);
            try @field(self.commands.entries, command_type.handle).put(command.id, command);
        }
    };

    return ecce;
}