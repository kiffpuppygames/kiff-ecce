const std = @import("std");

const ids = @import("ids.zig");
const strings = @import("strings.zig");
const ecce = @import("ecce.zig");

pub const ComponentReferences = std.AutoArrayHashMap(u64, u64);

pub const ComponentInfo = struct 
{
    component_type: type,
    component_type_id: u64 = undefined,
};

pub fn generate_component_infos(component_types: []const type) [component_types.len]ComponentInfo
{
    var component_infos: [component_types.len]ComponentInfo = undefined;
    inline for (component_types, 0..) |component_type, i| 
    {
        component_infos[i] = ComponentInfo 
        {
            .component_type = component_type,
            .component_type_id = i,
        };
    }

    return component_infos;
}

pub fn create_component(data_type: type, collection_handle: [:0]const u8) type
{
    const Component = comptime struct 
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

    return Component;
}

pub fn create_component_register(component_infos: []const ComponentInfo) type
{
    const num_components = component_infos.len;
    var struct_fields: [component_infos.len * 2]std.builtin.Type.StructField = undefined;
    inline for (component_infos, 0..) |component_info, i| 
    {
        struct_fields[i] = std.builtin.Type.StructField {
            .name = component_info.component_type.handle,
            .type = std.AutoArrayHashMap(u64, comptime component_info.component_type),
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(component_info.component_type),
        };
    }

    inline for (component_infos, 0..) |component_info, i| 
    {
        struct_fields[num_components + i] = std.builtin.Type.StructField {
            .name = component_info.component_type.handle ++ "_next_id",
            .type = u64,
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(u64),
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

    const ComponentRegister = struct 
    {
        const Self = @This();

        entries: Entries,
        const infos= component_infos;

        pub fn new(allocator: *const std.mem.Allocator) Self 
        {
            var entries: Entries = undefined;

            inline for (Self.infos) |component_info| 
            {
                @field(entries,  try strings.to_lower_case(component_info.component_type.handle)) = std.AutoArrayHashMap(u64, component_info.component_type).init(allocator.*);
            }

            return Self 
            {                
                .entries = entries,
            };
        }

        pub fn deinit(self: *Self) void 
        {
            inline for (infos) |component_info| 
            {
                @field(self.entries, component_info.runtime_name).deinit();
            }
        }
    };

    return ComponentRegister;
}