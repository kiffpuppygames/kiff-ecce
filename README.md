# Kiff-ECCE Framework

***This framework is a work in progress. At this point in time, only Entities and Components are implemented. The framework is not being built for performance yet; optimizations will come later, as I am currently focusing on the API's ergonomics.***

The Kiff-ECCE Framework is an architectural pattern that leverages Entities, Components, Commands, Events, and Command Handlers to build scalable and maintainable systems. It is a variation on the standard ECS pattern but does not include Queries, focusing instead on the dynamic interaction between commands and events to drive the system's behavior.

## Key Concepts

- **Entities**: The primary objects in the system, identified by unique IDs.
- **Components**: Data containers attached to entities, representing various aspects of the entity's state.
- **Commands**: Actions that can be performed on entities, often resulting in state changes.
- **Events**: Notifications triggered by commands, used to inform other parts of the system about state changes.
- **Command Handlers**: Functions or methods that process commands and generate events.

## Example

***Examples will be provided once I have a minimally functional API.***