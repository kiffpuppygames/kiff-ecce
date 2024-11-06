const std = @import("std");

const strings = @import("strings.zig");
const ids = @import("ids.zig");
const ecce = @import("ecce.zig");

pub fn create_commnad(data_type: type, collection_handle: [:0]const u8) type
{
    const Command = comptime struct 
    { 
        const Self = @This();
        pub const handle: [:0]const u8 = collection_handle;
        pub const t_id: u64 = ids.hash_type_name_64(@typeName(data_type));

        id: u64, 
        entity: ecce.Entity,         
        data: data_type,

        pub fn new() Self 
        {
            return Self { .id = 0, .entity = 0, .data = undefined };
        }
    };

    return Command;
}

pub fn create_command_register(command_types: []const type) type
{
    var struct_fields: [command_types.len]std.builtin.Type.StructField = undefined;
    inline for (command_types, 0..) |command_type, i| 
    {
        struct_fields[i] = std.builtin.Type.StructField {
            .name = command_type.handle,
            .type = std.AutoArrayHashMap(u64, comptime command_type),
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(command_type),
        };
    }

    const Entries: type = @Type(.{            
        .@"struct" = .{
            .layout = .auto,
            .fields = &struct_fields,
            .is_tuple = false,
            .decls = &[_]std.builtin.Type.Declaration{}
        },
    });

    const CommandRegister = struct 
    {
        const Self = @This();        
        const cmd_types = command_types;

        entries: Entries,

        pub fn new(allocator: *const std.mem.Allocator) Self 
        {
            var entries: Entries = undefined;

            inline for (Self.cmd_types) |command_type| 
            {
                @field(entries,  try strings.to_lower_case(command_type.handle)) = std.AutoArrayHashMap(u64, command_type).init(allocator.*);
            }

            return Self 
            {                
                .entries = entries,
            };
        }

        pub fn deinit(self: *Self) void 
        {
            inline for (cmd_types) |command_type| 
            {
                @field(self.entries, command_type.handle).deinit();
            }
        }
    };

    return CommandRegister;
}