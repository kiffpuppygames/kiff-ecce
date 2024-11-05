const std = @import("std");

pub fn to_lower_case(input: []const u8) ![:0]const u8 
{
    const input_len = input.len;

    var buffer: [input_len:0]u8 = undefined;

    for (input, 0..) |c, i| 
    {
        buffer[i] = std.ascii.toLower(c);
    }
    
    return &buffer;
}