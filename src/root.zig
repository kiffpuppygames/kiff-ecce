pub const strings = @import("strings.zig");
pub const ids = @import("ids.zig");
const ecce = @import("ecce.zig");

pub const ECCE = ecce.ECCE;

pub const createEcce = ecce.createEcce;

pub const components = struct 
{
    pub const create_component = @import("components.zig").create_component;
};

const cmds = @import("commands.zig");
pub const commands = struct 
{    
    pub const CommandId = cmds.CommandId;
    pub const Category = cmds.Category;
};