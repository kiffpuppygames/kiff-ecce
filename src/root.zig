pub const strings = @import("strings.zig");
pub const ids = @import("ids.zig");
pub const ecce = @import("ecce.zig");

pub const components = struct 
{
    pub const create_component = @import("components.zig").create_component;
};


pub const commands = struct 
{
    pub const create_command = @import("commands.zig").create_command;
};