## zfetch 

⚡A simple, *fetch-inspired system information tool written in Zig. This project serves as a basic example of a command-line application in Zig, focusing on a simple, modular design that is easy to expand. Running the program will currently produce output similar to this:

```
OS       : linux
Kernel   : 6.5.0-10-generic
Hostname : my-zig-devbox
User     : noro
Shell    : zsh
Uptime   : 1d 4h 22m
```

### Features

Currently, zfetch displays the following system information:

* Operating System
* Kernel Version
* Hostname
* Current User
* Default Shell
* System 
* Uptime

### Prerequisites

To build and run this project, you will need the Zig compiler installed on your system.

* This code is confirmed to work with Zig version 0.13.0.

### Building and Usage 

1. Clone this repository (or ensure your files are in a dedicated folder).

2. Navigate into the project directory. 

To build and run the program in one step:

```
zig build run
```

To build the executable separately:

```
zig build
```

The binary will be created at ```./zig-out/bin/zfetch```. 

You can run it directly from your terminal.

### How to Extend zfetch 

The program is fairly simple because I'm not a programmer. I like to tinker. It's made to be easily extensible. To add a new piece of information (e.g., CPU model), you only need to do two things:

1. Write a new "fetch" function in ```src/main.zig```

Create a function that returns the information you want as a ```anyerror![]u8```.

```
// Example for getting a CPU model
fn getCpu() anyerror![]u8 {
    // Your logic to read /proc/cpuinfo or similar would go here.
    return std.fmt.allocPrint(allocator, "AMD Ryzen 9 5900X", .{}); // for example
}
```
2. Add the new function to the ```fetch_items``` arraySimply add a new FetchItem struct to the list, pointing to your new function.

```
const fetch_items = [_]FetchItem{
    .{ .label = "OS", .fetchFn = &getOs },
    .{ .label = "Kernel", .fetchFn = &getKernel },
    .{ .label = "Hostname", .fetchFn = &getHostname },
    .{ .label = "User", .fetchFn = &getUsername },
    .{ .label = "Shell", .fetchFn = &getShell },
    .{ .label = "Uptime", .fetchFn = &getUptime },
    .{ .label = "CPU", .fetchFn = &getCpu }, // <-- Add your new item here!
};
```

The program will automatically pick up the new item, display its label, and align the output correctly.

## License

This project is licensed under the GPL License.