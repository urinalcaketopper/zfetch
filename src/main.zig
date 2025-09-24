const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const FetchItem = struct {
    label: []const u8,
    fetchFn: *const fn () anyerror![]u8,
};

fn getOs() anyerror![]u8 {
    const info = std.posix.uname();
    return std.fmt.allocPrint(allocator, "{s}", .{info.sysname});
}

fn getKernel() anyerror![]u8 {
    const info = std.posix.uname();
    return std.fmt.allocPrint(allocator, "{s}", .{info.release});
}

fn getHostname() anyerror![]u8 {
    var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const hostname = try std.posix.gethostname(&buf);
    return std.fmt.allocPrint(allocator, "{s}", .{hostname});
}

fn getUsername() anyerror![]u8 {
    return std.process.getEnvVarOwned(allocator, "USER");
}

fn getShell() anyerror![]u8 {
    const shell_path = try std.process.getEnvVarOwned(allocator, "SHELL");
    defer allocator.free(shell_path);

    const shell_name = std.fs.path.basename(shell_path);
    return std.fmt.allocPrint(allocator, "{s}", .{shell_name});
}

fn getUptime() anyerror![]u8 {
    const file = try std.fs.cwd().openFile("/proc/uptime", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    const stream = reader.reader();

    var buf: [32]u8 = undefined;
    const uptime_str = (try stream.readUntilDelimiterOrEof(&buf, ' ')) orelse return error.NoUptimeFound;

    const total_seconds = try std.fmt.parseFloat(f64, uptime_str);

    const days = @as(u64, @intFromFloat(total_seconds / 86400));
    const hours = @as(u64, @intFromFloat(total_seconds / 3600)) % 24;
    const minutes = @as(u64, @intFromFloat(total_seconds / 60)) % 60;

    return std.fmt.allocPrint(allocator, "{}d {}h {}m", .{ days, hours, minutes });
}

const fetch_items = [_]FetchItem{
    .{ .label = "OS", .fetchFn = &getOs },
    .{ .label = "Kernel", .fetchFn = &getKernel },
    .{ .label = "Hostname", .fetchFn = &getHostname },
    .{ .label = "User", .fetchFn = &getUsername },
    .{ .label = "Shell", .fetchFn = &getShell },
    .{ .label = "Uptime", .fetchFn = &getUptime },
};

pub fn main() !void {
    defer _ = gpa.deinit();

    const stdout = std.io.getStdOut().writer();

    var max_label_len: usize = 0;
    for (fetch_items) |item| {
        if (item.label.len > max_label_len) {
            max_label_len = item.label.len;
        }
    }

    for (fetch_items) |item| {
        try stdout.print("{s}", .{item.label});

        const padding_needed = max_label_len - item.label.len;
        var i: usize = 0;
        while (i < padding_needed) : (i += 1) {
            try stdout.print(" ", .{});
        }

        try stdout.print(" : ", .{});

        const result = item.fetchFn() catch |err| {
            try stdout.print("Error: {any}\n", .{err});
            continue;
        };
        defer allocator.free(result);

        try stdout.print("{s}\n", .{result});
    }
}
