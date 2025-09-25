const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const DistroArt = struct {
    id: []const u8,
    art: []const []const u8,
};

const distro_art_list = [_]DistroArt{
    .{
        .id = "void",
        .art = &.{
            "  \\\\  //",
            "   \\\\// ",
            "    //  ",
            "   //\\\\ ",
            "  //  \\\\",
        },
    },
    .{
        .id = "arch",
        .art = &.{
            "    /\\   ",
            "   /  \\  ",
            "  /\\´`\\ ",
            " / ____ \\",
            "/__/    \\__\\",
        },
    },
    .{
        .id = "ubuntu",
        .art = &.{
            "   _   ",
            " _| |  ",
            "| | |  ",
            "| |_|  ",
            " \\___/ ",
        },
    },
    .{
        .id = "debian",
        .art = &.{
            "  __-´´-,  ",
            " / ´´´´´/  ",
            "| | ´´´´´| ",
            "| \\-....-/ ",
            " \\-.....-/  ",
        },
    },
    .{
        .id = "fedora",
        .art = &.{
            "  ______",
            " /´     |",
            "|  ´---,´",
            "| |     ",
            "|_|      ",
        },
    },
    .{
        .id = "linux",
        .art = &.{
            "    .--.   ",
            "   |o_o |  ",
            "   |:_/ |  ",
            "  //   \\ \\ ",
            " (|     | )",
            "/´\\_   _/`\\",
            "\\___)=(___/",
        },
    },
};

const FetchItem = struct {
    label: []const u8,
    fetchFn: *const fn () anyerror![]u8,
};

fn getOs() anyerror![]u8 {
    const info = std.posix.uname();
    return std.fmt.allocPrint(allocator, "{s}", .{info.sysname});
}

fn getDistroName() anyerror![]u8 {
    const file = try std.fs.cwd().openFile("/etc/os-release", .{});
    defer file.close();

    var buffer: [1024]u8 = undefined;
    const bytes_read = try file.reader().readAll(&buffer);
    const content = buffer[0..bytes_read];

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "PRETTY_NAME=")) {
            var parts = std.mem.splitScalar(u8, line, '=');
            _ = parts.next();
            if (parts.next()) |name_raw| {
                const name_trimmed = std.mem.trim(u8, name_raw, "\"");
                return allocator.dupe(u8, name_trimmed);
            }
        }
    }
    return error.DistroNameNotFound;
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

fn getDistroId() ![]const u8 {
    const file = try std.fs.cwd().openFile("/etc/os-release", .{});
    defer file.close();

    var buffer: [1024]u8 = undefined;
    const bytes_read = try file.reader().readAll(&buffer);
    const content = buffer[0..bytes_read];

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "ID=")) {
            var parts = std.mem.splitScalar(u8, line, '=');
            _ = parts.next();
            if (parts.next()) |id_raw| {
                const id_trimmed = std.mem.trim(u8, id_raw, "\"");
                return allocator.dupe(u8, id_trimmed);
            }
        }
    }
    return error.DistroIdNotFound;
}

fn getArtForDistro(id: []const u8) []const []const u8 {
    for (distro_art_list) |distro| {
        if (std.mem.eql(u8, id, distro.id)) {
            return distro.art;
        }
    }
    return distro_art_list[distro_art_list.len - 1].art;
}

const fetch_items = [_]FetchItem{
    .{ .label = "Distribution", .fetchFn = &getDistroName },
    // .{ .label = "OS", .fetchFn = &getOs },
    .{ .label = "Kernel", .fetchFn = &getKernel },
    .{ .label = "Hostname", .fetchFn = &getHostname },
    .{ .label = "User", .fetchFn = &getUsername },
    .{ .label = "Shell", .fetchFn = &getShell },
    .{ .label = "Uptime", .fetchFn = &getUptime },
};

pub fn main() !void {
    defer _ = gpa.deinit();

    const stdout = std.io.getStdOut().writer();

    const distro_id = getDistroId() catch |err| blk: {
        std.log.warn("Could not detect distro ID ({s}), using fallback.", .{@errorName(err)});
        break :blk "linux";
    };
    defer if (!std.mem.eql(u8, distro_id, "linux")) allocator.free(distro_id);

    const art = getArtForDistro(distro_id);

    var fetched_info = std.ArrayList(struct {
        label: []const u8,
        value: []u8,
    }).init(allocator);
    defer {
        for (fetched_info.items) |info| allocator.free(info.value);
        fetched_info.deinit();
    }

    for (fetch_items) |item| {
        const value = item.fetchFn() catch |err| blk: {
            const error_message = try std.fmt.allocPrint(allocator, "Error: {s}", .{@errorName(err)});
            break :blk error_message;
        };
        try fetched_info.append(.{ .label = item.label, .value = value });
    }

    var max_art_width: usize = 0;
    for (art) |line| {
        if (line.len > max_art_width) max_art_width = line.len;
    }
    var max_label_len: usize = 0;
    for (fetched_info.items) |info| {
        if (info.label.len > max_label_len) max_label_len = info.label.len;
    }

    const max_lines = @max(art.len, fetched_info.items.len);
    var i: usize = 0;
    while (i < max_lines) : (i += 1) {
        if (i < art.len) {
            try stdout.print("{s}", .{art[i]});
            var p: usize = art[i].len;
            while (p < max_art_width) : (p += 1) {
                try stdout.print(" ", .{});
            }
        } else {
            var p: usize = 0;
            while (p < max_art_width) : (p += 1) {
                try stdout.print(" ", .{});
            }
        }

        try stdout.print("  ", .{});

        if (i < fetched_info.items.len) {
            const info = fetched_info.items[i];
            try stdout.print("{s}", .{info.label});
            var p: usize = info.label.len;
            while (p < max_label_len) : (p += 1) {
                try stdout.print(" ", .{});
            }
            try stdout.print(" : {s}", .{info.value});
        }

        try stdout.print("\n", .{});
    }
}
