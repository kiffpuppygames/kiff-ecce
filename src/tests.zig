const std = @import("std");

const ecce = @import("ecce.zig");
const components = @import("components.zig");

test "init ecce and add components" 
{
    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();

    const PlayerData = comptime struct { id: i32, name: []const u8 };
    const HealthData = comptime struct { value: i32 };
    
    const Player = comptime components.create_component(PlayerData, "player_components");
    const Health = comptime components.create_component(HealthData, "health_components");

    const component_types = [_]type {
        Player,
        Health,
    };

    const ECCE = comptime ecce.create_ecce(&component_types);

    var world = ECCE.new(&alloc.allocator());    
    defer world.deinit();

    const entity1: ecce.Entity = try world.add_entity();
    {
        const player1 = Player { .id = world.components.entries.player_components.values().len, .entity = entity1, .data = PlayerData { .id = 42, .name = "Guy" } };
        const health1 = Health { .id = world.components.entries.health_components.values().len, .entity = entity1, .data = HealthData { .value = 100 } };
        try world.add_component(entity1, player1);
        try world.add_component(entity1, health1);

        try std.testing.expectEqual(2, world.entities.get(entity1).?.values().len);
        try std.testing.expectEqual(player1.id, world.entities.get(entity1).?.get(Player.t_id).?);

        const stored_player = world.components.entries.player_components.get(player1.id).?;
        try std.testing.expectEqual(player1.data.name, stored_player.data.name);
        const stored_health = try world.get_component_by_id(Health, health1.id);
        try std.testing.expectEqual(health1.data.value, stored_health.data.value);
    }
    
    const entity2: ecce.Entity = try world.add_entity();
    {
        
        const player2 = Player { .id = world.components.entries.player_components.values().len, .entity = entity2, .data = PlayerData { .id = 42, .name = "Connor" } };
        const health2 = Health { .id = world.components.entries.health_components.values().len, .entity = entity2, .data = HealthData { .value = 150 } };
        try world.add_component(entity2, player2);
        try world.add_component(entity2, health2);

        try std.testing.expectEqual(2, world.entities.get(entity2).?.values().len);
        try std.testing.expectEqual(player2.id, world.entities.get(entity2).?.get(Player.t_id).?);
        
        const stored_player = world.components.entries.player_components.get(player2.id).?;
        try std.testing.expectEqual(player2.data.name, stored_player.data.name);
        const stored_health = try world.get_component_by_id(Health, health2.id);
        try std.testing.expectEqual(health2.data.value, stored_health.data.value);
    }

    try std.testing.expectEqual(world.entities.values().len, 2);
    try std.testing.expectEqual(world.components.entries.player_components.values().len, 2);
    try std.testing.expectEqual(world.components.entries.health_components.values().len, 2);
    
    try std.testing.expect(true);
}