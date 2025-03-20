
const std = @import("std");

const StringUnmanaged = @import("kiff_common").StringUnmanaged;
const Logger = @import("kiff_common").Logger;

const components = @import("components.zig");
const commands = @import("commands.zig");
const ecce = @import("ecce.zig");

// const FarewellCommandData = struct { target_entity: ecce.Entity, script_entity: ecce.Entity };
// const FarewellCommand = commands.create_command(FarewellCommandData);

// const GreetAllCommandData = struct { script_entity: ecce.Entity };
// const GreetAllCommand = commands.create_command(GreetAllCommandData);

// const FareAllCommandData = struct { script_entity: ecce.Entity };
// const FarewellAllCommand = commands.create_command(FareAllCommandData);

// const command_types = [_]type {
//     GreetCommand,
//     // FarewellCommand,
//     // GreetAllCommand,
//     // FarewellAllCommand,
// };

// const FarewellComponentData = struct { farewell_text: []const u8 };
// const FarewellComponent = components.create_component(FarewellComponentData, "farewell_components");

//const ECCE = ecce.create_ecce(&component_types, &command_types);

const EcceError = error {
    InvalidCommand,
    InvalidQueue,
    CommandIdIsNull,
    CommandIdAlreadySet,
};

// const PersonComponentData = struct { name: []const u8 };
// const PersonComponent = components.create_component(PersonComponentData, "person_components");
const PersonComponent = struct 
{
    const tag: ComponentTag = ComponentTag.personComponent;

    id: ?components.ComponentId = null,
    
    name: []const u8 = undefined,

    pub fn collectionName() [:0]const u8
    {
        return "personComponents";
    }

    pub fn getTag() ComponentTag {
        return tag;
    }
};

// Command definitions need to be explicit, this ensure the lsp can resolve the type. It also ensures clarity as to what is in the struct
// NOTE: Commands must implement fn queueName() [:0]const u8 and id: ?commands.CommandId
const GreetPersonCommand = struct 
{
    const tag: CommandTag = CommandTag.greetPersonCommand;
    const catetgory: commands.CommandCategory = commands.CommandCategory.TargetCommand;

    id: ?commands.CommandId = null,
    
    person_to_greet: components.ComponentId = undefined,
    greeting: []const u8 = undefined,

    pub fn getCategory() commands.CommandCategory {
        return catetgory;
    }

    pub fn getTag() CommandTag {
        return tag;
    }

    pub fn handle(self: *const GreetPersonCommand, allocator: std.mem.Allocator) !void 
    {
        const name = world.component_stores.get(PersonComponent.tag).?.get(self.person_to_greet).?.personComponent.name;
        var str = try StringUnmanaged.build(allocator, self.greeting, .{ name });
        defer str.deinit(allocator);
        Logger.info("{s}", .{ str.chars.items });
    }
};

const GreetAllPeopleCommand = struct 
{
    const tag: CommandTag = CommandTag.greetAllPeopleCommand;
    const catetgory: commands.CommandCategory = commands.CommandCategory.BatchCommand;

    id: ?commands.CommandId = null,
    greeting: []const u8 = undefined,

    pub fn getCategory() commands.CommandCategory {
        return catetgory;
    }

    pub fn getTag() CommandTag {
        return tag;
    }

    pub fn handle(self: *const GreetAllPeopleCommand, allocator: std.mem.Allocator) !void 
    {
        _ = allocator;
        Logger.debug("{s}", .{ self.greeting });
    }
};

const ComponentTag = enum 
{
    personComponent,
};

const Component = union(ComponentTag)
{
    personComponent: PersonComponent,
};

const CommandTag = enum 
{
    greetPersonCommand,
    greetAllPeopleCommand
};

const Command = union(CommandTag)
{
    greetPersonCommand: GreetPersonCommand, 
    greetAllPeopleCommand: GreetAllPeopleCommand,
    // GreetAllCommand,
    // FarewellAllCommand,
};

// const command_handlers = [_]commands.CommandHandler {
//     handleGreetEntityCommands,
// };

//const World = ecce.create_ecce(&component_types, Command);

const World = ecce.ECCE(Command, Component, ComponentTag);
var world: World = undefined;

pub fn main() !void 
{
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer {
        const chk = gpa.deinit();
        if (chk == .leak)
        {
            Logger.debug("Leak Detected!", .{});
            @panic("Leak!!!!");
        }
    }

    world = try World.init(gpa.allocator());
    defer world.deinit();

    const e1 = try world.createEntity(gpa.allocator());
    const e2 = try world.createEntity(gpa.allocator());
    const e3 = try world.createEntity(gpa.allocator());
    const e4 = try world.createEntity(gpa.allocator());

    Logger.debug("Entity {d} created", .{ e1 });
    Logger.debug("Entity {d} created", .{ e2 });
    Logger.debug("Entity {d} created", .{ e3 });
    Logger.debug("Entity {d} created", .{ e4 });

    var p1 = PersonComponent { .name = "John Rambo" };
    var p2 = PersonComponent { .name = "Rocky Balboa" };
    var p3 = PersonComponent { .name = "King Shark" };
    var p4 = PersonComponent { .name = "John Spartan" };

    p1 = try world.addComponentToEntity(p1 , e1 );
    p2 = try world.addComponentToEntity(p2 , e2 );
    p3 = try world.addComponentToEntity(p3 , e3 );
    p4 = try world.addComponentToEntity(p4 , e4 );

    const entity1 = world.entities.getPtr(e1);
    
    Logger.debug("Entity {d} has {d} components", .{ e1, entity1.?.component_refs.items.len });

    var p5 = PersonComponent { .name = "Marion Cobretti" };
    p5 = try world.addComponentToEntity( p5, e1 );
    
    Logger.debug("Entity {d} has {d} components", .{ e1, entity1.?.component_refs.items.len });

    try world.dispatchCommand(GreetAllPeopleCommand { .greeting = "Hello to all!!!" });
    try world.dispatchCommand(GreetPersonCommand { .greeting = "Hi ¬!", .person_to_greet = p1.id.? });
    try world.dispatchCommand(GreetPersonCommand { .greeting = "Whatsuuup ¬!!", .person_to_greet = p2.id.? });
    try world.dispatchCommand(GreetPersonCommand { .greeting = "Greetings ¬!", .person_to_greet = p3.id.? });
    try world.dispatchCommand(GreetPersonCommand { .greeting = "Holla ¬!", .person_to_greet = p4.id.? });
    try world.dispatchCommand(GreetPersonCommand { .greeting = "Stay a while and listen ¬", .person_to_greet = p5.id.? });

    try world.handle_commands(gpa.allocator());

    //try world.dispatchCommand(GreetAllPeopleCommand { .greeting = "Hello Everyone" });
    // const GreetComponentData = struct { greeting_text: []const u8 };
    // const GreetComponent = components.create_component( GreetComponentData, "greet_components");
    // const component_types = [_]type {
    // GreetComponent,
    // //FarewellComponent,
    // PersonComponent,
}

fn greetPerson(person: PersonComponent, comptime cmd: GreetPersonCommand) void
{
    //const people = world.component_stores.get(ComponentTag.personComponent) .get(ComponentTag.personComponent).?.values();
    
    Logger.debug(cmd.greeting, .{ person.name });

    // for (people) |person| {        
    // }
}

// fn handleGreetEntityCommands(world: *World) !void
// {
//     while (world.command_queues.greetEntityCommandQueue.pop()) |_|
//     {
//         Logger.Info("Hello");ecce.EntityId

    // const cmd = GreetCommand { .entity_to_greet = 0, .greeting = "Hello {}" };

    // std.log.debug(cmd.greeting, .{ cmd.entity_to_greet });

    // var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer alloc.deinit();

   
    // var world = ECCE.new(&alloc.allocator());    
    // defer world.deinit();

    // const script_entity: ecce.Entity = try world.add_entity();
    // try world.add_component(script_entity, GreetComponent 
    // { 
    //     .id = world.get_next_component_id(), 
    //     .entity = script_entity, 
    //     .data = GreetComponentData { .greeting_text = "Hello" }
    // });

    // // try world.add_component(script_entity, FarewellComponent 
    // // {
    // //     .id = world.get_next_component_id(), 
    // //     .entity = script_entity, 
    // //     .data = FarewellComponentData { .farewell_text = "Goodbye" }
    // // });
    
    // const person_1_entity: ecce.Entity = try world.add_entity();
    // try world.add_component(person_1_entity, PersonComponent 
    // { 
    //     .id = world.get_next_component_id(), 
    //     .entity = person_1_entity, 
    //     .data = PersonComponentData { .name = "John" }
    // });        
        
    // const person_2_entity: ecce.Entity = try world.add_entity();
    // try world.add_component(person_2_entity, PersonComponent 
    // { 
    //     .id = world.get_next_component_id(),
    //     .entity = person_2_entity, 
    //     .data = PersonComponentData { .name = "Jane" }
    // });    

    // try world.dispatch_command(GreetCommand 
    // { 
    //     .command = commands.Command { .id = world.get_next_command_id() }, 
    //     .entity_to_greet = person_1_entity,
    //     .greeting = "Hello {s}."
    // });
    
    // try world.dispatch_command(FarewellCommand 
    // { 
    //     .id = world.get_next_command_id(), 
    //     .data = FarewellCommandData {.target_entity = person_1_entity, .script_entity = script_entity } 
    // });

    // try world.dispatch_command(GreetCommand 
    // { 
    //     .id = world.get_next_command_id(), 
    //     .data = GreetCommandData { .target_entity = person_2_entity, .script_entity = script_entity } 
    // });
    
    // try world.dispatch_command(FarewellCommand 
    // { 
    //     .id = world.get_next_command_id(), 
    //     .data = FarewellCommandData { .target_entity = person_2_entity, .script_entity = script_entity }
    // });

    // try world.dispatch_command(GreetAllCommand 
    // { 
    //     .id = world.get_next_command_id(), 
    //     .data = GreetAllCommandData { .script_entity = script_entity } 
    // });
    
    // try world.dispatch_command(FarewellAllCommand 
    // { 
    //     .id = world.get_next_command_id(), 
    //     .data = FareAllCommandData { .script_entity = script_entity } 
    // });

    
    // try handle_greet_commands(&world);
    // //try handle_farewell_commands(&world);

    // std.debug.print("\n", .{});

    //try handle_greet_all_commands(&world);
    //try handle_farewell_all_commands(&world);  
//}

// fn handle_greet_commands(world: *ECCE) !void 
// {
//     for (world.commands.entries.greet_commands.values()) |cmd| 
//     {   
//         const greet_component = try world.get_component_by_entity(cmd.data.?.script_entity, GreetComponent);          
//         const person_component = try world.get_component_by_entity(cmd.data.?.target_entity, PersonComponent);        
//         std.debug.print("\n{s} {s}", .{ greet_component.data.greeting_text, person_component.data.name });
//     }
// }

// fn handle_farewell_commands(world: *ECCE) !void 
// {
//     for (world.commands.entries.farewell_commands.values()) |cmd| 
//     {   
//         const farewell_component = try world.get_component_by_entity(cmd.data.?.script_entity, FarewellComponent);          
//         const person_component = try world.get_component_by_entity(cmd.data.?.target_entity, PersonComponent);        
//         std.debug.print("\n{s} {s}", .{ farewell_component.data.farewell_text , person_component.data.name });
//     }
// }

// fn handle_greet_all_commands(world: *ECCE) !void 
// {
//     for (world.commands.entries.greet_all_commands.values()) |cmd| 
//     {
//         for (world.components.entries.person_components.values()) |person_component| 
//         {
//             const greet_component = try world.get_component_by_entity(cmd.data.?.script_entity, GreetComponent);          
//             std.debug.print("\n{s} {s}", .{ greet_component.data.greeting_text , person_component.data.name });
//         }
//     }
// }

// fn handle_farewell_all_commands(world: *ECCE) !void 
// {
//     for (world.commands.entries.farewell_all_commands.values()) |cmd| 
//     {
//         for (world.components.entries.person_components.values()) |person_component| 
//         {
//             const farewell_component = try world.get_component_by_entity(cmd.data.?.script_entity, FarewellComponent);          
//             std.debug.print("\n{s} {s}", .{ farewell_component.data.farewell_text, person_component.data.name });
//         }
//     }
// }

