# Kiff-ECCE Framework

***This framework is a work in progress. At present the framework is not being built for performance; optimizations will come later, as I am currently focusing on the API's ergonomics.***

The Kiff-ECCE Framework is an architectural pattern that leverages Entities, Components, Commands, Events, and Command Handlers to build scalable and maintainable systems. It is a variation on the standard ECS pattern and does not include Queries, focusing instead on the dynamic interaction between commands and events to drive the system's behavior.

## Progress

- [x] Entities
- [x] Components
- [x] Commands
- [ ] Events
- [ ] Command Handlers
- [ ] Schedules
- [ ] Resources

## Key Concepts

- **Entities**: The primary objects in the system, identified by unique IDs.
- **Components**: Data containers attached to entities, representing various aspects of the entity's state.
- **Commands**: Actions that can be performed on entities, often resulting in state changes.
- **Events**: Notifications triggered by commands, used to inform other parts of the system about state changes.
- **Command Handlers**: Functions or methods that process commands and generate events.

## Example
 
***These example are simple, as the API is not fully mature yet.***

By using Zigs comptime functionality we can build dynamic structs allowing us to create concrete implimentaions of components, entities and commands. To register a component or command you can do as follows:

### Component Creation

```zig

const PersonComponentData = struct { name: []const u8 };
const PersonComponent = components.create_component(PersonComponentData, "person_components");

const component_types = [_]type {
    PersonComponent,
};

```

### Command Creation

```zig

const GreetCommand = comptime components.create_command( .{}, "greet_commands);

const command_types = [_]type {
    GreetCommand,
};

```

### Create ECCE

```zig

const ECCE = ecce.create_ecce(&component_types, &command_types);

```

### Adding Commands and Components

```zig

const person_2_entity: ecce.Entity = try world.add_entity();
try world.add_component(person_2_entity, PersonComponent 
{ 
    .id = world.get_next_component_id(),
    .entity = person_2_entity, 
    .data = PersonComponentData { .name = "Jane" }
});    

try world.dispatch_command(GreetCommand 
{ 
    .id = world.get_next_command_id(), 
    .data = GreetCommandData { .target_entity = person_1_entity, .script_entity = script_entity }
});

```

### Access Commands and Components

```zig

for (world.commands.entries.greet_all_commands.values()) |cmd| 
{
    for (world.components.entries.person_components.values()) |person_component| 
    {
        const greet_component = try world.get_component_by_entity(cmd.data.?.script_entity, GreetComponent);          
        std.debug.print("\n{s} {s}", .{ greet_component.data.greeting_text , person_component.data.name });
    }
}

```

**A complete example can be found in [main.zig](https://github.com/kiffpuppygames/kiff-ECCE/blob/master/src/main.zig)**


