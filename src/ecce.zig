const std = @import("std");

const Logger = @import("kiff_common").Logger;

const components = @import("components.zig");
const commands = @import("commands.zig");

pub const EntityId = u64;

pub const EcceError = error {
    UnionFieldNotFound
};

pub fn ECCE(comptime command_types: type, comptime component_types: type, comptime component_tags: type) type 
{ 
    return struct {
        const Self = @This();
        const Command = command_types;
        const Component = component_types;
        const ComponentTag = component_tags;

        entities: std.AutoArrayHashMap(EntityId, Entity()) = undefined,
        command_queues: std.AutoArrayHashMap(commands.CommandCategory, std.ArrayList(Command)) = undefined,
        component_stores: std.AutoArrayHashMap(ComponentTag, std.AutoArrayHashMap(components.ComponentId, Component)) = undefined,
        _next_entity_id: EntityId = 0,
        _next_command_id: commands.CommandId = 0,
        _next_component_id: u64 = 0,

        pub fn init(allocator: std.mem.Allocator) !Self
        {
            var cmd_queues = std.AutoArrayHashMap(commands.CommandCategory, std.ArrayList(Command)).init(allocator);
            inline for (std.meta.fields(commands.CommandCategory)) |field| {
                const value = std.ArrayList(Command).init(allocator);
                try cmd_queues.put(@enumFromInt(field.value), value);
                Logger.debug("{s} queue initilized", .{ field.name });
            }

            var comp_stores = std.AutoArrayHashMap(ComponentTag, std.AutoArrayHashMap(components.ComponentId, Component)).init(allocator);
            inline for (std.meta.fields(ComponentTag)) |comp_tag_field| {
                const tag: ComponentTag = @enumFromInt(comp_tag_field.value);
                try comp_stores.put( tag, std.AutoArrayHashMap(components.ComponentId, Component).init(allocator));
            }

            return Self {
                .entities = std.AutoArrayHashMap(EntityId, Entity()).init(allocator),
                .command_queues = cmd_queues,
                .component_stores = comp_stores,
            };
        }

        pub fn Entity() type {
            return struct {
                id: EntityId = undefined,
                component_refs: std.ArrayList(EntityComponentRefrence()) = undefined
            }; 
        }

        pub fn EntityComponentRefrence() type {
            return struct { component_tag: ComponentTag, component_id: components.ComponentId };
        }

        pub fn dispatchCommand(self: *Self, command: anytype) !void 
        {
            //const T = @TypeOf(command);
            var mut_command = command;

            if (mut_command.id != null)
            {
                Logger.warn("The Command Id has already been set for {any}, id {?}: Command ids should only be set at dispatch. The command id will now be set to the next available command id.", .{ command, command.id });
            }
            
            mut_command.id = self._next_command_id;
            self._next_command_id += 1;

            try self.command_queues.getPtr(@TypeOf(command).getCategory()).?.append(@unionInit(Command, @tagName(@TypeOf(command).getTag()), command));            
        }

        pub fn handle_commands(self: *Self, allocator: std.mem.Allocator) !void
        {
            inline for (std.meta.tags(commands.CommandCategory)) |cat| {                
                while (self.command_queues.getPtr(cat).?.pop()) |cmd|
                {
                    switch (cat) {                        
                        commands.CommandCategory.BatchCommand => {                            
                            switch (cmd) {
                                inline else => |val| try val.handle(allocator)
                            }
                        },
                        commands.CommandCategory.TargetCommand => {
                            switch (cmd) {
                                inline else => |val| try val.handle(allocator)
                            }
                        }
                    }  
                }
            }
        }

        pub fn addComponentToEntity(self: *Self, component: anytype, entity_id: EntityId) !@TypeOf(component) 
        {
            var mut_component = component;
            if (mut_component.id != null)
            {
                Logger.err("The Component Id has already been set for {any}, id {?}: Component ids should only be set upon being added to the ecce. Are trying to add a component that already exists? Component will not be added.", .{ component, component.id });                
            }
            else 
            {
                mut_component.id = self._next_component_id;
                self._next_component_id += 1;

                const tag: ComponentTag = @TypeOf(component).getTag();
                const comp_union = @unionInit(Component, @tagName(tag), mut_component);

                //const tag = getComponentTag(comp_union);
                try self.component_stores.getPtr(tag).?.put(mut_component.id.?, comp_union);

                const component_ref = EntityComponentRefrence() { .component_tag = tag, .component_id =  mut_component.id.?};
                var entity = self.entities.getPtr(entity_id).?;
                try entity.component_refs.append(component_ref);
            }

            return mut_component;
        }

        // fn getUnionValue(component: Component) anytype {
        //     inline for (std.meta.fields(Components)) |field| {
        //         const field_type = @field(Components, field.name);
        //         const field_value = ;

        //         // Check if the field has a value
        //         switch (field_value) {
        //             field_type => {
        //                 std.debug.print("Field {} has value: {}\n", .{field.name, field_value});
        //             },
        //             else => {
        //                 std.debug.print("Field {} does not have a value.\n", .{field.name});
        //             },
        //         }
        //     }
        // }      

        pub fn getComponentTag(component: anytype) ComponentTag {
            const T = @TypeOf(component);
            inline for (std.meta.fields(Component)) |field| {
                if (@TypeOf(@field(Component, field.name)) == T) {
                    // This is the field that matches the component
                    return @field(Component, field.name).tag;
                }
            }
            @panic("Unknown component type");
        }

        pub fn getUnionFieldForComponent(comptype: type) !std.builtin.Type.UnionField {
            inline for (std.meta.fields(Component)) |field| {
                const field_type = @TypeOf(@field(Component, field.name));
                if (field_type == comptype) {
                    return @field(Component, field.name); // Return the field to use in the union
                }
            }
            return EcceError.UnionFieldNotFound; // Return null if no match was found
        }

        pub fn createEntity(self: *Self, allocator: std.mem.Allocator) !EntityId
        {
            try self.entities.put(self._next_entity_id, Entity() { .id = self._next_entity_id, .component_refs = std.ArrayList(EntityComponentRefrence()).init(allocator)});
            const entity_id = self._next_entity_id;
            self._next_entity_id += 1;
            return entity_id;
        }

        pub fn deinit(self: *Self) void
        {
            inline for (std.meta.tags(commands.CommandCategory)) |cat| {    
                Logger.debug("Cleaning Up {s} queue, has {d} unhandled commands", . { @tagName(cat), self.command_queues.get(cat).?.items.len });            
                self.command_queues.getPtr(cat).?.deinit();
            }
            self.command_queues.deinit();

            var comp_store_itr = self.component_stores.iterator();
            while (comp_store_itr.next()) |entry| {
                    Logger.debug("Cleaning up {} {}", .{ entry.value_ptr.*.values().len, entry.key_ptr } );
                    entry.value_ptr.*.deinit(); 
            }
            Logger.debug("Cleaning up {d} component stores.", .{ self.component_stores.values().len});
            self.component_stores.deinit();

            for (self.entities.values()) |entity| {                
                entity.component_refs.deinit();                
            }
            Logger.debug("Cleaning up {d} entities.", .{ self.entities.values().len});
            self.entities.deinit();    
        }
    };
}

// pub fn create_ecce(component_types: []const type, command_union: type) type
// {
//     //const component_infos = comptime generateComponentInfos(component_types);

//     const ecce = struct 
//     {
        // const Self = @This();
        // const cmd_union = command_union;
        // const ComponentCollections = components.ComponentCollection(component_types);
        
        // var next_component_id: u64 = 0;
        // var next_command_id: commands.CommandId = 0;
        // var next_entity_id: EntityId = 0;

        // allocator: std.mem.Allocator,
        // //entities: std.AutoArrayHashMap(EntityId, Entity),

        // components_allocator: std.heap.ArenaAllocator,
        // components: ComponentCollections,

        // command_queue_allocator: std.heap.ArenaAllocator,
        // command_queue: std.ArrayList(cmd_union),

        // const GreetPersonCommand = struct{};

        // pub fn init(alloc: std.mem.Allocator) Self 
        // {  
        //     var command_queue_allocator = std.heap.ArenaAllocator.init(DefaultChildAllocator);
        //     var components_allocator = std.heap.ArenaAllocator.init(DefaultChildAllocator);


        //     var component_collections: ComponentCollections = undefined;
        //     inline for (component_types) |component_type| {
        //         @field(component_collections, component_type.collectionName()) = std.AutoArrayHashMap(components.ComponentId, component_type).init(components_allocator.allocator());
        //     }

        //     return Self 
        //     {
        //         .allocator = alloc, 
        //         .entities = std.AutoArrayHashMap(EntityId, Entity).init(alloc),

        //         .components_allocator = components_allocator,
        //         .components = component_collections,

        //         .command_queue_allocator = command_queue_allocator,
        //         .command_queue = std.ArrayList(cmd_union).init(command_queue_allocator.allocator()),
        //     };
        // }

        // pub fn deinit(self: *Self) void 
        // {
        //     inline for (component_types) |comp_type| {
        //         @field(self.components, comp_type.collectionName()).deinit();
        //     }

        //     self.components_allocator.deinit();

        //     self.command_queue.deinit();
        //     self.command_queue_allocator.deinit();

        //     self.entities.deinit();
        // }

        // pub fn handleCommnands(self: *const Self) !void
        // {
        //     for (self.command_handlers) |handler|
        //     {
        //         handler();
        //     }
        // }

        // pub fn addCommandHanlders(self: *Self, handlers: []commands.CommandHandler) !void
        // {
        //     self.command_handlers = handlers;
        // }

        // pub fn addEntity(self: *Self, allocator: std.mem.Allocator) !EntityId 
        // {
        //     const entity_id: EntityId = getNextEntityId();
        //     try self.entities.put(entity_id, Entity { .id = entity_id , .component_refs = std.ArrayList(self.EntityComponentRefrence()).init(allocator) } );            
        //     return entity_id;
        // }

        // pub fn addComponentToEntity(self: *Self, comptime component: anytype, entity_id: EntityId) !void 
        // {
        //     const T = @TypeOf(component);
        //     var mut_component = component;

        //     // for (self.components.values()) |value| {
        //     //     value.deint();
        //     // }
        //     // self.components.deinit();
        //     if (mut_component.id != null)
        //     {
        //         Logger.err("The Component Id has already been set for {any}, id {?}: Component ids should only be set upon being added to the ecce. Are trying to add a component that already exists? Component will not be added.", .{ component, component.id });                
        //     }
        //     else 
        //     {
        //         mut_component.id = getNextComponentId();
        //         try @field(self.components, T.collectionName()).put(mut_component.id.?, mut_component);

        //         const component_ref = self.EntityComponentRefrence() { .component_type_id = getComponentTypeId(@TypeOf(component)), .component_id =  mut_component.id.?};
        //         var entity = self.entities.getPtr(entity_id).?;
        //         try entity.component_refs.append(component_ref);
        //     }
        // }

        // pub fn getComponentTypeId(comptime T: type) components.ComponentTypeId 
        // {
        //     inline for (component_types, 0..) |comp, i|
        //     {
        //         if (T == comp) return i;
        //     }
        //     @compileError("Component type not registered: " ++ @typeName(T));          
        // }

        // pub fn getComponentById(self: *Self, component_type: type, component_id: u64) !component_type 
        // {
        //     return @field(self.components.entries, component_type.handle).get(component_id).?;
        // }

        // // pub fn getComponentByEntity(self: *Self, entity: Entity, component_type: type) !component_type 
        // // {
        // //     const component_id = self.entities.get(entity).?.get(component_type.t_id);
        // //     return self.get_component_by_id(component_type, component_id.?);
        // // }

        // pub fn dispatchCommand(self: *Self, command: anytype) !void 
        // {
        //     const T = @TypeOf(command);
        //     var mut_command = command;

        //     if (mut_command.id != null)
        //     {
        //         Logger.warn("The Command Id has already been set for {any}, id {?}: Command ids should only be set at dispatch. The command id will now be set to the next available command id.", .{ command, command.id });
        //     }
            
        //     mut_command.id = getNextCommandId();   

        //     if (@field(self.command_queues, T.queueName())._is_initilized)
        //     {
        //         try @field(self.command_queues, T.queueName()).append(command);
        //     }
        //     else 
        //     {
        //         Logger.debug("Commnad Queue has not been initilized: {}", .{ @TypeOf(@field(self.command_queues, T.queueName())) });
        //         @panic("OOM");
        //     }

            
        // }

        // inline fn getNextEntityId() EntityId
        // {
        //     const entity_id = next_entity_id;
        //     next_entity_id += 1;
        //     return entity_id;
        // }

        // inline fn getNextComponentId() components.ComponentTypeId 
        // {
        //     const id = next_component_id;
        //     next_component_id += 1;
        //     return id;
        // }

        // inline fn getNextCommandId() commands.CommandId 
        // {
        //     const id = next_command_id;
        //     next_command_id += 1;
        //     return id;
        // }
    //};

//     return ecce;
// }

// inline fn generateComponentIds(component_types: []type) std.AutoArrayHashMap(type, components.ComponentTypeId)
// {
//     var component_type_id_map = std.AutoHashMap(type, components.ComponentTypeId).;





//     var component_infos: [self.component_types.len]ComponentInfo = undefined;
//     inline for (self.component_types, 0..) |component_type, i| 
//     {
//         component_type_id_map.put(component_type, self.getNextComponentId());
//         component_infos[i] = ComponentInfo 
//         {
//             .component_type = component_type,
//             .component_type_id = i,
//         };
//     }

//     return component_infos;
// // }

// pub fn makeStruct(struct_name: []const u8, comptime default_args: anytype, comptime custom_args: anytype) type 
// {
//     const default_info = @typeInfo(@TypeOf(default_args));
//     const custom_info = @typeInfo(@TypeOf(custom_args));

//     if (default_info != .@"struct" or custom_info != .@"struct") 
//     {
//         std.log.debug("Invaild command or component: {?}, {?}", .{ default_info, custom_info });
//     }

//     comptime var fields: [default_info.@"struct".fields.len + custom_info.@"struct".fields.len]std.builtin.Type.StructField = undefined;
//     comptime var new_struct: type = undefined;

//     comptime 
//     {
//         const name_field = std.builtin.Type.StructField {
//             .name = "struct_type_name",
//             .type = [struct_name.len]u8,
//             .default_value_ptr = @ptrCast(struct_name),
//             .is_comptime = true,
//             .alignment = @alignOf([struct_name.len]u8),
//         };
//         fields[0] = name_field;

//         for (default_info.@"struct".fields, 0..) |field, i| {
//             var field_value: std.builtin.Type.StructField = undefined;
//             field_value = .{
//                 .name = field.name,
//                 .type = field.defaultValue().?,
//                 .default_value_ptr = null,
//                 .is_comptime = false,
//                 .alignment = @alignOf(field.type),
//             };
//             fields[i + 1] = field_value;
//         }

//         for (custom_info.@"struct".fields, 0..) |field, i| {
//             var field_value: std.builtin.Type.StructField = undefined;
//             field_value = .{
//                 .name = field.name,
//                 .type = field.defaultValue().?,
//                 .default_value_ptr = null,
//                 .is_comptime = false,
//                 .alignment = @alignOf(field.type),
//             };
//             fields[i + default_info.@"struct".fields.len] = field_value;
//         }

//         new_struct = @Type(.{
//             .@"struct" = .{
//                 .layout = .auto,
//                 .fields = &fields,
//                 .is_tuple = false,
//                 .decls = &[_]std.builtin.Type.Declaration {  }          
//             },
//         });

//         //@compileLog(fields);
//     }

//     //@compileLog(@typeInfo(new_struct));

//     return new_struct;
// }