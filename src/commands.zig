const std = @import("std");

const strings = @import("strings.zig");
const ids = @import("ids.zig");
const ecce = @import("ecce.zig");

const kiff_common = @import("kiff_common");
const Logger = kiff_common.Logger;

pub const CommandId = u64;
pub const CommandHandler = *fn(world: *anyopaque, cmd_type: type) void;

pub const Category = enum 
{
    batch_command,
    target_command,
};

pub const BaseCommand = struct 
{    
    _id: ?CommandId = null,

    // pub fn handle(self: *const BaseCommand, allocator: std.mem.Allocator) !void 
    // {
    //     const name = world.component_stores.get(PersonComponent.tag).?.get(self.person_to_greet).?.personComponent.name;
    //     var str = try StringUnmanaged.build(allocator, self.greeting, .{ name });
    //     defer str.deinit(allocator);
    //     Logger.info("{s}", .{ str.chars.items });
    // }
};

pub fn generateCommandTag(comptime command_data_types: []const type) type 
{
    var fields: [command_data_types.len]std.builtin.Type.EnumField = undefined;

    for (command_data_types, 0..) |cmd_data_type, i| 
    {
        const name = @typeName(cmd_data_type);
        const start_index = std.mem.lastIndexOf(u8, name, ".").? + 1;
        var name_arr: [name.len - start_index - 4:0]u8 = undefined;
        std.mem.copyBackwards(u8, &name_arr, name[start_index..name.len - 4]);
        name_arr[0] = std.ascii.toLower(name_arr[0]); 

        fields[i] = std.builtin.Type.EnumField {
            .name = &name_arr,
            .value = i
        };
    }

    return @Type(.{ 
        .@"enum" = .{
            .fields = &fields,
            .tag_type = u64,
            .decls = &.{},
            .is_exhaustive = true
        } 
    });
}

pub fn generateCommands(command_data_types: []const type, tags: type) type 
{
    var fields: [command_data_types.len]std.builtin.Type.UnionField = undefined;

    for (command_data_types, 0..) |cmd_data_type, i| 
    {
        const tag: tags = @enumFromInt(i);
        const new_cmd = ceateCommand(cmd_data_type, tag);

        const name = @typeName(new_cmd);
        const start_index = std.mem.lastIndexOf(u8, name, ".").? + 1;
        var name_arr: [name.len - start_index - 1:0]u8 = undefined;
        std.mem.copyBackwards(u8, &name_arr, name[start_index..name.len - 1]);
        //name_arr[0] = std.ascii.toUpper(name_arr[0]); 
        //@compileLog(name_arr);
        fields[i] = std.builtin.Type.UnionField {
            .name = &name_arr,
            .type = new_cmd,
            .alignment = @alignOf(new_cmd),
        };
    }

    return @Type(.{ 
        .@"union" = .{
            .layout = .auto,
            .tag_type = tags,
            .fields = &fields,
            .decls = &.{},
        } 
    });
}

fn ceateCommand(data: type, tag: anytype) type
{
    const data_info = @typeInfo(data);
    const base_info = @typeInfo(BaseCommand);

    const tag_type = @TypeOf(tag);
    const tag_field = std.builtin.Type.StructField { .name = "_tag", .is_comptime = false, .default_value_ptr = &tag, .type = tag_type, .alignment = @alignOf(tag_type)};

    const fields = base_info.@"struct".fields ++ data_info.@"struct".fields ++ .{ tag_field };
    
    var new_struct = base_info;

    new_struct.@"struct".fields = fields;

    return @Type(new_struct);
}

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