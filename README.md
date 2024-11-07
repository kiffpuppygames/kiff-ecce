# Kiff-ECCE Framework

***This framework is a work in progress. At present the framework is not being built for performance; optimizations will come later, as I am currently focusing on the API's ergonomics.***

The Kiff-ECCE Framework is an architectural pattern that leverages Entities, Components, Commands, Events, and Command Handlers to build scalable and maintainable systems. It is a variation on the standard ECS pattern but does not include Queries, focusing instead on the dynamic interaction between commands and events to drive the system's behavior.

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

By using Zigs comptime functionality we can build dynamic structs allowing us to create concrete implimentaions of components, entities and commands. To register a component or commnad you can do as follows:

### Component Creation

```zig



```

### Commnad Creation

```zig

const GreetCommand = comptime components.create_command( .{}, "greet_commands);
const FarwellCommnad = comptime components.create_commnad(.{}, "farewell_commands");

const command_types = [_]type 
{
    GreetCommand,
    FarwellCommnad,
};

```

### Create ECCE
```zig

```

A complete example can be found in [main.zig](https://github.com/kiffpuppygames/kiff-ECCE/blob/master/src/main.zig)


