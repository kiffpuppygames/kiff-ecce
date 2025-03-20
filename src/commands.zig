const std = @import("std");

const strings = @import("strings.zig");
const ids = @import("ids.zig");
const ecce = @import("ecce.zig");

const Logger = @import("kiff_common").Logger;

pub const CommandId = u64;
pub const CommandHandler = *fn(world: *anyopaque, cmd_type: type) void;

pub const CommandCategory = enum(u64) 
{
    BatchCommand,
    TargetCommand,
};

// pub fn CommandQueue(commands: type) type
// {
//     return struct 
//     {
//         const Self = @This();        
        
//         gpa: std.heap.GeneralPurposeAllocator(.{}),
//         queue: std.ArrayList(commands),
//         _is_initilized: bool = false,

//         pub fn init() Self
//         {
//             const queue = 

//             return Self {
//                 .gpa = gpa,
//                 .queue = queue,
//                 ._is_initilized = true
//             };
//         }

//         pub fn append(self: *Self, command: anytype) !void
//         {   
//             try self.queue.append(command);
//         }

//         pub fn pop(self: *Self) !void
//         {   
//             try self.queue.pop();
//         }

//         pub fn deinit(self: *Self) void
//         {
//             self.queue.deinit();

//             if (self.gpa.deinit() == .leak) 
//             {
//                 Logger.err("Memory Leak in CommandQueue: {}", .{ @TypeOf(self.queue) });
//             }
//         }
//     };
// }

// pub fn CommandQueues(comptime command_types: []const type) type
// {
//     comptime var fields: [command_types.len]std.builtin.Type.StructField = undefined;

//     inline for (command_types, 0..) |command_type, i| 
//     {
//         if (validateCommand(command_type))
//         {
//             const queue_type = CommandQueue(command_type);

//             const command_queue = std.builtin.Type.StructField {
//                 .name = command_type.queueName(),
//                 .type = queue_type,
//                 .default_value_ptr = null,
//                 .is_comptime = false,
//                 .alignment = @alignOf(queue_type),
//             };

//             fields[i] = command_queue;
//         }
//     }

//     const queues = @Type(.{            
//         .@"struct" = .{
//             .layout = .auto,
//             .fields = &fields,
//             .is_tuple = false,
//             .decls = &[_]std.builtin.Type.Declaration{},
            
//         },
//     });

//     return queues;
// }

pub fn validateCommand(T: type) bool
{
    const type_info = @typeInfo(T);

    var id = false;
    var queue_name = false;

    if (type_info == .@"struct")
    {
        const info = type_info.@"struct";

        inline for (info.fields) |field|
        {
            if (std.mem.eql(u8, field.name, "id") and field.type == ?CommandId)
            {
                id = true;
            }  
        }

        inline for (info.decls) |decl|
        {
            if (std.mem.eql(u8, decl.name, "queueName"))
            {
                queue_name = true;
            }  
        }
    }

    if (!id) { @compileError("Command does not implement filed id: ?CommandId"); }
    if (!queue_name) { @compileError("Command does not implement fn queueName() [:0] const u8"); }

    if (queue_name and id) return true;

    return false;
}