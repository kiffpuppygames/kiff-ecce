const std = @import("std");

const ids = @import("ids.zig");
const strings = @import("strings.zig");
const ecce = @import("ecce.zig");

pub const ComponentId = u64;
pub const ComponentTypeId = u64;

pub const ComponentReferences = std.AutoArrayHashMap(u64, u64); //maps the componment id to its type

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

pub fn ComponentCollection(component_types: []const type) type
{
    var struct_fields: [component_types.len] std.builtin.Type.StructField = undefined;
    
    inline for (component_types, 0..) |component_type, i| 
    {
        if (validateComponent(component_type))
        {
            struct_fields[i] = std.builtin.Type.StructField {
                .name = component_type.collectionName(),
                .type = std.AutoArrayHashMap(ComponentId, component_type),
                .default_value_ptr = null,
                .is_comptime = false,
                .alignment = @alignOf(std.AutoArrayHashMap(ComponentId, component_type)),
            };
        }
    }

    return @Type(.{            
        .@"struct" = .{
            .layout = .auto,
            .fields = &struct_fields,
            .is_tuple = false,
            .decls = &[_]std.builtin.Type.Declaration{}
        },
    });
}

pub fn validateComponent(T: type) bool
{
    const type_info = @typeInfo(T);

    var id = false;
    var collection_name = false;

    if (type_info == .@"struct")
    {
        const info = type_info.@"struct";

        inline for (info.fields) |field|
        {
            if (std.mem.eql(u8, field.name, "id") and field.type == ?ComponentId)
            {
                id = true;
            }  
        }

        inline for (info.decls) |decl|
        {
            if (std.mem.eql(u8, decl.name, "collectionName"))
            {
                collection_name = true;
            }  
        }
    }

    if (!id) { @compileError("Component does not implement filed id: ?ComponentId"); }
    if (!collection_name) { @compileError("Component does not implement fn collectionName() [:0] const u8"); }

    if (collection_name and id) return true;

    return false;
}