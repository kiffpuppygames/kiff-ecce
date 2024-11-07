
const std = @import("std");

const components = @import("components.zig");
const commands = @import("commands.zig");
const ecce = @import("ecce.zig");

const GreetCommandData = struct { target_entity: ecce.Entity, script_entity: ecce.Entity };    
const GreetCommand = commands.create_command(GreetCommandData, "greet_commands");

const FarewellCommandData = struct { target_entity: ecce.Entity, script_entity: ecce.Entity };
const FarewellCommand = commands.create_command(FarewellCommandData, "farewell_commands");

const GreetAllCommandData = struct { script_entity: ecce.Entity };
const GreetAllCommand = commands.create_command(GreetAllCommandData, "greet_all_commands");

const FareAllCommandData = struct { script_entity: ecce.Entity };
const FarewellAllCommand = commands.create_command(FareAllCommandData, "farewell_all_commands");

const command_types = [_]type {
    GreetCommand,
    FarewellCommand,
    GreetAllCommand,
    FarewellAllCommand,
};

const GreetComponentData = struct { greeting_text: []const u8 };
const GreetComponent = components.create_component( GreetComponentData, "greet_components");

const FarewellComponentData = struct { farewell_text: []const u8 };
const FarewellComponent = components.create_component(FarewellComponentData, "farewell_components");

const PersonComponentData = struct { name: []const u8 };
const PersonComponent = components.create_component(PersonComponentData, "person_components");

const component_types = [_]type {
    GreetComponent,
    FarewellComponent,
    PersonComponent,
};

const ECCE = ecce.create_ecce(&component_types, &command_types);

pub fn main() !void 
{
    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();

   
    var world = ECCE.new(&alloc.allocator());    
    defer world.deinit();

    const script_entity: ecce.Entity = try world.add_entity();
    try world.add_component(script_entity, GreetComponent 
    { 
        .id = world.get_next_component_id(), 
        .entity = script_entity, 
        .data = GreetComponentData { .greeting_text = "Hello" }
    });

    try world.add_component(script_entity, FarewellComponent 
    {
        .id = world.get_next_component_id(), 
        .entity = script_entity, 
        .data = FarewellComponentData { .farewell_text = "Goodbye" }
    });
    
    const person_1_entity: ecce.Entity = try world.add_entity();
    try world.add_component(person_1_entity, PersonComponent 
    { 
        .id = world.get_next_component_id(), 
        .entity = person_1_entity, 
        .data = PersonComponentData { .name = "John" }
    });        
        
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
    
    try world.dispatch_command(FarewellCommand 
    { 
        .id = world.get_next_command_id(), 
        .data = FarewellCommandData {.target_entity = person_1_entity, .script_entity = script_entity } 
    });

    try world.dispatch_command(GreetCommand 
    { 
        .id = world.get_next_command_id(), 
        .data = GreetCommandData { .target_entity = person_2_entity, .script_entity = script_entity } 
    });
    
    try world.dispatch_command(FarewellCommand 
    { 
        .id = world.get_next_command_id(), 
        .data = FarewellCommandData { .target_entity = person_2_entity, .script_entity = script_entity }
    });

    try world.dispatch_command(GreetAllCommand 
    { 
        .id = world.get_next_command_id(), 
        .data = GreetAllCommandData { .script_entity = script_entity } 
    });
    
    try world.dispatch_command(FarewellAllCommand 
    { 
        .id = world.get_next_command_id(), 
        .data = FareAllCommandData { .script_entity = script_entity } 
    });

    
    try handle_greet_commands(&world);
    try handle_farewell_commands(&world);

    std.debug.print("\n", .{});

    try handle_greet_all_commands(&world);
    try handle_farewell_all_commands(&world);  
}

fn handle_greet_commands(world: *ECCE) !void 
{
    for (world.commands.entries.greet_commands.values()) |cmd| 
    {   
        const greet_component = try world.get_component_by_entity(cmd.data.?.script_entity, GreetComponent);          
        const person_component = try world.get_component_by_entity(cmd.data.?.target_entity, PersonComponent);        
        std.debug.print("\n{s} {s}", .{ greet_component.data.greeting_text, person_component.data.name });
    }
}

fn handle_farewell_commands(world: *ECCE) !void 
{
    for (world.commands.entries.farewell_commands.values()) |cmd| 
    {   
        const farewell_component = try world.get_component_by_entity(cmd.data.?.script_entity, FarewellComponent);          
        const person_component = try world.get_component_by_entity(cmd.data.?.target_entity, PersonComponent);        
        std.debug.print("\n{s} {s}", .{ farewell_component.data.farewell_text , person_component.data.name });
    }
}

fn handle_greet_all_commands(world: *ECCE) !void 
{
    for (world.commands.entries.greet_all_commands.values()) |cmd| 
    {
        for (world.components.entries.person_components.values()) |person_component| 
        {
            const greet_component = try world.get_component_by_entity(cmd.data.?.script_entity, GreetComponent);          
            std.debug.print("\n{s} {s}", .{ greet_component.data.greeting_text , person_component.data.name });
        }
    }
}

fn handle_farewell_all_commands(world: *ECCE) !void 
{
    for (world.commands.entries.farewell_all_commands.values()) |cmd| 
    {
        for (world.components.entries.person_components.values()) |person_component| 
        {
            const farewell_component = try world.get_component_by_entity(cmd.data.?.script_entity, FarewellComponent);          
            std.debug.print("\n{s} {s}", .{ farewell_component.data.farewell_text, person_component.data.name });
        }
    }
}

