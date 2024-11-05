const std = @import("std");

pub fn hash_type_name_64(type_name: []const u8) u64 
{
    var hash: u64 = 5381;
    for (type_name) |c| {
        const mul_result = @mulWithOverflow(hash, 33);
        const add_result = @addWithOverflow(mul_result[0], @as(u64, c));
        hash = add_result[0];
    }
    return hash;
}