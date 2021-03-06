<div align="center">

# Shrun

## Run Shell Commands Concurrently

[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/tbidne/shrun?include_prereleases&sort=semver)](https://github.com/tbidne/shrun/releases/)
[![MIT](https://img.shields.io/github/license/tbidne/shrun?color=blue)](https://opensource.org/licenses/MIT)

[![nix](https://img.shields.io/github/workflow/status/tbidne/shrun/nix/main?label=nix%209.2&logo=nixos&logoColor=85c5e7&labelColor=2f353c)](https://github.com/tbidne/shrun/actions/workflows/nix_ci.yaml)
[![cabal 9.2](https://img.shields.io/github/workflow/status/tbidne/shrun/cabal_9-2/main?label=9.2&logo=haskell&logoColor=655889&labelColor=2f353c)](https://github.com/tbidne/shrun/actions/workflows/cabal_9-2.yaml)
[![stack nightly](https://img.shields.io/github/workflow/status/tbidne/shrun/stack_nightly/main?label=stack%20nightly&logoColor=white&labelColor=2f353c)](https://github.com/tbidne/shrun/actions/workflows/stack_nightly.yaml)
[![style](https://img.shields.io/github/workflow/status/tbidne/shrun/style/main?label=style&logoColor=white&labelColor=2f353c)](https://github.com/tbidne/shrun/actions/workflows/style_ci.yaml)

![demo](./examples/demo.gif)

</div>

---

### Table of Contents
- [Motivation](#motivation)
- [Introduction](#introduction)
- [Configuration](#configuration)
  - [Core Functionality](#core-functionality)
    - [Config](#config)
    - [No Config](#no-config)
    - [Timeout](#timeout)
  - [Logging](#logging)
    - [Command Log](#command-log)
    - [File Log](#file-log)
    - [File Log Mode](#file-log-mode)
    - [Disable Log](#disable-log)
  - [Log Formatting](#log-formatting)
    - [Key Hide](#key-hide)
    - [Strip Control](#strip-control)
    - [File Log Strip Control](#file-log-strip-control)
    - [Command Name Truncation](#command-name-truncation)
    - [Command Line Truncation](#command-line-truncation)
  - [Miscellaneous](#miscellaneous)
    - [Default Config](#default-config)
- [Building](#building)
  - [Cabal](#cabal)
  - [Stack](#stack)
  - [Nix](#nix)

# Motivation

`shrun` was borne of frustration. Suppose you run several shell commands on a regular basis e.g. updates after pulling the latest code. You can run these manually like:

```sh
cmd1
cmd2
cmd3
...
```

But that can be a lot of repetitive typing, especially when the commands are longer. Thus you write an alias:

```sh
alias run_commands="cmd1 && cmd2 && cmd3 ..."
```

All well and good, but this approach has several deficiencies:

1. You do not receive any information about how long your commands have been running. If any of the commands are long-lived, how do you know when it's been "too long" and you should cancel them? You can look at a clock or use a stopwatch, but that requires remembering every time you run the command, which is certainly unsatisfying.

1. These commands are all run synchronously even though there may be no relation between them. For example, if you have three commands that each take 5 minutes, the combination will take 15 minutes. This is usually unnecessary.

1. Related to above, if any command fails then subsequent ones will not be run. This can be frustrating, as you may kick off a run and leave, only to return and find out that later, longer-running commands never ran because of some trivial error in the beginning.

1. It does not scale. Imagine you have variations of `cmd3` you want to run under different circumstances. You could create multiple aliases:

        
        alias run_commands_cmd3a="cmd1 && cmd2 && cmd3a"
        alias run_commands_cmd3b="cmd1 && cmd2 && cmd3b"

    But this is messy and grows exponentially in the number of aliases for each variation.

`shrun` purports to overcome these limitations.

# Introduction

In a nut-shell (????), `shrun` is a wrapper around running shell commands. For instance:

```sh
shrun "some long command" "another command"
```

Will run `some long command` and `another command` concurrently.

A running timer is provided, and stdout/stderr will be updated when a command finishes/crashes, respectively.

Note: `shrun` colors its logs, and the examples shown here _should_ use these colors. Unfortunately github does not render them, so you will have to view this markdown file somewhere else to see them.

# Configuration

`shrun` can be configured by either CLI args or a `toml` config file.

## Core Functionality

### Config

**Arg:** `-c, --config PATH`

**Description**: Path to TOML config file. If this argument is not given we automatically look in the Xdg config directory e.g. `~/config/shrun/config.toml`.

Examples can be found in [./examples](./examples).


#### Legend

In addition to providing an alternative to CLI args, the config file has a `legend` section. This allows one to define aliases for commands. Each alias has a key and a value. The value can either be a single unit or a list of units, where a unit is either a command literal (e.g. bash expression) or a recursive reference to another alias.

**Example:** For instance, given the section

```toml
legend = [
  { key = 'cmd1', val = 'echo "command one"' },
  { key = 'cmd2', val = 'cmd1' },
  { key = 'cmd3', val = 'cmd2' },
  { key = 'cmd4', val = 'command four' },
  { key = 'all', val = ['cmd3', 'cmd4', 'echo hi'] },
]
```

Then the command

```sh
shrun --config=path/to/config all "echo cat"
```

Will run `echo "command one"`, `command four`, `echo hi` and `echo cat` concurrently. A picture is worth a thousand words:

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun --config=examples/config.toml all "echo cat"</span>
<span style="color: #69ff94">[Info] [echo cat] Success. Time elapsed: 0 seconds</span>
<span style="color: #69ff94">[Info] [echo hi] Success. Time elapsed: 0 second</span>
<span style="color: #69ff94">[Info] [echo "command one"] Success. Time elapsed: 0 second</span>
<span style="color: #ff6e6e">[Error] [command four] Error: '/bin/sh: line 1: four: command not found. Time elapsed: 0 seconds</span>
<span style="color: #d6acff">[Info] Finished! Total time elapsed: 0 seconds</span></code>
</pre>

Note: duplicate keys will cause a parse error to be thrown when loading. Cyclic keys are also disallowed, though these will only throw if you actually try to execute one (i.e. merely having cyclic definitions in the legend will not throw an error).

### No Config

**Arg:** `--no-config`

**Description**: Overrides toml file config regardless of how it was obtained i.e. explicit --config or implicit reading of the Xdg config file. Used for when a config file exists at the expected Xdg location, but we want to ignore it.

### Timeout

**Arg:** `-t, --timeout NATURAL`

**Description:** The provided timeout must be either a raw integer (interpreted as seconds), or a "time string" e.g. `1d2m3h4s`, `3h20s`. All integers must be non-negative. If the timeout is reached, then all remaining commands will be cancelled.

**Example:**

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun --timeout 8 "sleep 5" "sleep 10" "sleep 15"</span>
<span style="color: #69ff94">[Info] [sleep 5] Success. Time elapsed: 5 seconds</span>
<span style="color: #d3d38e">[Warn] Timed out, cancelling remaining commands: sleep 10, sleep 15</span>
<span style="color: #d6acff">[Info] Finished! Total time elapsed: 9 seconds</span></code>
</pre>

## Logging

### Command Log

**Arg:** `-l, --cmd-log`

**Description:** The default behavior is to swallow logs for the commands themselves. This flag gives each command a console region in which its logs will be printed. Only the latest log per region is shown at a given time.

Note: When commands have complicated output, they logs can interfere with each other (indeed even overwrite themselves). We attempt to mitigate such situations, though see [Strip Control](#strip-control).

**Example:**

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun --cmd-log "for i in {1..10}; do echo hi; sleep 1; done"</span>
<span style="color:">[Command] [for i in {1..10}; do echo hi; sleep 1; done] hi</span>
<span style="color: #a3fefe">[Info] Running time: 7 seconds</span></code>
</pre>

vs.

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun "for i in {1..10}; do echo hi; sleep 1; done"</span>
<span style="color: #a3fefe">[Info] Running time: 7 seconds</span></code>
</pre>

Note: Both the commands' `stdout` and `stderr` are treated the same, logged with the same formatting. This is because many shell programs perform redirection like `echo ... >&2` (i.e. redirect `stdout` to `stderr`). Not only does this mean we need to take both if we do not want to skip any output, but it also means it does not make sense to try to differentiate the two anymore, as that information has been lost.

Practically speaking, this does not have much effect, just that if a command dies while `--cmd-log` is enabled, then the final `[Error] ...` output may not have the most relevant information. See [File Log](#file-log) for details on investigating command failure.

### File Log

**Arg:** `-f, --file-log [PATH]`

**Description**: If a path is supplied, all logs will additionally be written to the supplied file. Furthermore, command logs will be written to the file irrespective of `--cmd-log`. Console logging is unaffected. This can be useful for investigating command failures. If the path is empty (e.g. `--file-log=`, `-f ''`), we will write to the Xdg config directory e.g. `~/.config/shrun/log`.

**Example:**

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun --file-log=out.log --cmd-log "sleep 2" "bad" "for i in {1..3}; do echo hi; sleep 1; done"</span>
<span style="color: #ff6e6e">[Error] [for i in {1..10}; do echo hi; sleep 1; done] hi</span>
<span style="color: #69ff94">[Info] [sleep 2] Success. Time elapsed: 2 seconds</span>
<span style="color: #69ff94">[Info] [for i in {1..3}; do echo hi; sleep 1; done] Success. Time elapsed: 3 seconds</span>
<span style="color: #d6acff">[Info] Finished! Total time elapsed: 3 seconds</span></code>
</pre>

<pre>
<code><span style="color: #ff79c6">$</span><span> cat out.log</span>
<span style="color:">[2022-05-26 11:25:59.150635686 UTC] [Command] [for i in {1..3}; do echo hi; sleep 1; done] hi</span>
<span style="color:">[2022-05-26 11:25:59.152213816 UTC] [Command] [bad] /bin/sh: line 1: bad: command not found</span>
<span style="color:">[2022-05-26 11:25:59.152253545 UTC] [Error] [bad] /bin/sh: line 1: bad: command not found. Time elapsed: 0 seconds</span>
<span style="color:">[2022-05-26 11:26:00.151610059 UTC] [Command] [for i in {1..3}; do echo hi; sleep 1; done] hi</span>
<span style="color:">[2022-05-26 11:26:01.150768195 UTC] [Info] [sleep 2] Success. Time elapsed: 2 seconds</span>
<span style="color:">[2022-05-26 11:25:59.150635686 UTC] [Command] [for i in {1..3}; do echo hi; sleep 1; done] hi</span>
<span style="color:">[2022-05-26 11:26:02.153745075 UTC] [Info] Finished! Total time elapsed: 3 seconds</span></code>
</pre>

### File Log Mode

**Arg:** `--file-log-mode <append | write>`

**Description:** Mode in which to open the log file. Defaults to write.

### Disable Log

**Arg:** `-d, --disable-log`

**Description**: This option globally disables all logging i.e. ordinary logs and those created via `--cmd-log` and `--file-log`. As most uses will want at least the default success/error messages and timers, this option is primarily intended for debugging or testing where logging is undesirable.

## Log Formatting

### Key Hide

**Arg:** `-k, --key-hide`

**Description:** By default, we display the key name from the legend file over the actual command that was run, if the former exists. This flag instead shows the literal command. Commands without keys are unaffected.

**Example:**

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun --key-hide --cmd-log --config=examples/config.toml skynet</span>
<span style="color:">[Command] [echo "preparing nuclear missil-- i mean gift baskets"; sleep 10] preparing nuclear missil-- i mean gift baskets</span>
<span style="color: #a3fefe">[Info] Running time: 7 seconds</span></code>
</pre>

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun --key-hide --cmd-log --config=examples/config.toml skynet</span>
<span style="color: #69ff94">[Success] [echo "preparing nuclear missil-- i mean gift baskets"; sleep 10] Success. Time elapsed: 10 seconds</span>
<span style="color: #d6acff">[Info] Finished! Total time elapsed: 10 seconds</span></code>
</pre>

rather than the usual

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun --cmd-log --config=examples/config.toml skynet</span>
<span style="color:">[Command] [skynet] preparing nuclear missil-- i mean gift baskets</span>
<span style="color: #a3fefe">[Info] Running time: 7 seconds</span></code>
</pre>

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun --cmd-log --config=examples/config.toml skynet</span>
<span style="color: #69ff94">[Success] [skynet] Success. Time elapsed: 10 seconds</span>
<span style="color: #d6acff">[Info] Finished! Total time elapsed: 10 seconds</span></code>
</pre>

Naturally, this does not affect commands that do not have a key (i.e. those not in a legend file). Also, if the commands are defined recursively, then the key name will be the _final_ key.

### Strip Control

**Arg:** `-s,--strip-control <all | smart | none>`

**Description:** Control characters can wreak layout havoc with the `--cmd-log` option, thus we include this option. `all` strips all such chars. `none` does nothing i.e. all chars are left untouched. The default `smart` attempts to strip only the control chars that affect layout (e.g. cursor movements) and leaves others unaffected (e.g. colors). This has the potential to be the 'prettiest' as:

* Simple formatting is left intact.
* The layout should not be damaged.

Though it is possible to miss some chars. This option is experimental and subject to change.

**Example:**

Note: In the following examples, `\033[35m` and `\033[3D` are ansi escape codes. The former sets the text color to magenta, and the latter resets the cursor to the left by 3 places i.e. partially overwrites the previous characters. We also include the options `-lx10` (show command logs and truncate command name to 10 chars) to make the output easier to read.

`all` strips _all_ control characters: `\033` in this case. The means all special formatting / control will be omitted.
<pre>
<code><span style="color: #ff79c6">$</span><span> shrun -lx10 --strip-control all "echo -e ' foo \033[35m hello \033[3D bye '; sleep 5"</span>
<span style="color:">[Command] [echo -e...] foo  hello  bye</span>
<span style="color: #a3fefe">[Info] Running time: 3 seconds</span></code>
</pre>

`none` leaves all control characters in place. In this case, we will apply both the text coloring (`\033[35m`) and text overwriting (`\033[3D`).
<pre>
<code><span style="color: #ff79c6">$</span><span> shrun -lx10 --strip-control none "echo -e ' foo \033[35m hello \033[3D bye '; sleep 5"</span>
<span style="color:">[Command] [echo -e...] foo <span style="color: magenta"> hel bye</span></span>
<span style="color: #a3fefe">[Info] Running time: 3 seconds</span></code>
</pre>

`smart` removes the control chars but leaves the text coloring, so we will have the magenta text but not overwriting.
<pre>
<code><span style="color: #ff79c6">$</span><span> shrun -lx10 --strip-control smart "echo -e ' foo \033[35m hello \033[3D bye '; sleep 5"</span>
<span style="color:">[Command] [echo -e...] foo <span style="color: magenta"> hello  bye</span</span>
<span style="color: #a3fefe">[Info] Running time: 3 seconds</span></code>
</pre>

### File Log Strip Control

**Arg:** `-f, --file-log-strip-control <all | smart | none>`

**Description**: Like [`--strip-control`](#strip-control), but applies to file logs. If none is given defaults to `all`.

### Command Name Truncation

**Arg:** `-x, --cmd-name-trunc NATURAL`

**Description:** Non-negative integer that limits the length of commands/key-names in the console logs. Defaults to no truncation. This affects everywhere the command/key-name shows up (i.e. in command logs or final success/error message). File logs created via `--file-log` are unaffected.

**Example:**

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun --cmd-log --cmd-name-trunc 10 "for i in {1..3}; do echo hi; sleep 1; done"</span>
<span style="color:">[Command] [for i i...] hi</span>
<span style="color: #a3fefe">[Info] Running time: 2 seconds</span></code>
</pre>

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun --cmd-log --cmd-name-trunc 10 "for i in {1..3}; do echo hi; sleep 1; done"</span>
<span style="color: #69ff94">[Success] [for i i...] Success. Time elapsed: 3 seconds</span>
<span style="color: #d6acff">[Info] Finished! Total time elapsed: 3 seconds</span></code>
</pre>

### Command Line Truncation

**Arg:** `-y, --cmd-line-trunc <NATURAL | detect>`

**Description:** Non-negative integer that limits the length of logs produced via `--cmd-log` in the console logs. Can also be the string literal `detect` or `d`, to detect the terminal size automatically. Defaults to no truncation. This does not affect file logs with `--file-log`.

**Example:**

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun --cmd-log --cmd-line-trunc 80 "echo 'some ridiculously long command i mean is this really necessary' && sleep 5"</span>
<span style="color:">[Command] [echo 'some ridiculously long command i mean is this really ne...</span>
<span style="color: #a3fefe">[Info] Running time: 3 seconds</span></code>
</pre>

<pre>
<code><span style="color: #ff79c6">$</span><span> shrun --cmd-log --cmd-line-trunc detect "echo 'some ridiculously long command i mean is this really necessary' && sleep 5"</span>
<span style="color:">[Command] [echo 'some ridiculously long command i mean is this really necessary' && sleep 5] some ridiculously long command...</span>
<span style="color: #a3fefe">[Info] Running time: 3 seconds</span></code>
</pre>

## Miscellaneous

### Default Config

**Arg:** `--default-config`

**Description:** Writes a default configuration to `stdout`.

# Building

## Prerequisites

You will need one of:

* [cabal-install 2.4+](https://www.haskell.org/cabal/download.html) and [ghc 9.2](https://www.haskell.org/ghcup/)
* [stack](https://docs.haskellstack.org/en/stable/README/#how-to-install)
* [nix](https://nixos.org/download.html)

If you have never built a haskell program before, `cabal` + `ghcup` is probably the best choice.

## Cabal

You will need `ghc` and `cabal-install`. From there `shrun` can be built with `cabal build` or installed globally (i.e. `~/.cabal/bin/`) with `cabal install`.

## Stack

Like `cabal`, `shrun` can be built locally or installed globally (e.g. `~/.local/bin/`) with `stack build` and `stack install`, respectively.

## Nix

### From source

Building with `nix` uses [flakes](https://nixos.wiki/wiki/Flakes). `shrun` can be built with `nix build`, which will compile and run the tests.

To launch a shell with various tools (e.g. `cabal`, `hls`), run `nix develop`. After that we can launch a repl with `cabal repl` or run the various tools on our code. At this point you could also build via `cabal`, though you may have to first run `cabal update`. This will fetch the needed dependencies from `nixpkgs`.

### Via nix

Because `shrun` is a flake, it be built as part of a nix expression. For instance, if you want to add `shrun` to `NixOS`, your `flake.nix` might look something like:

```nix
{
  description = "My flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    shrun-src.url= "github:tbidne/shrun/main";
  };

  outputs = { self, nixpkgs, shrun-src, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = system;
      };
      shrun = shrun-src.defaultPackage.${system};
      # Alternative if you want tests disabled.
      #shrun = pkgs.haskell.lib.dontCheck shrun-src.defaultPackage.${system};
    in
    {
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = system;
          modules = [
            (import ./configuration.nix { inherit pkgs shrun; })
          ];
        };
      };
    };
}
```

Then in `configuration.nix` you can simply have:

```nix
{ pkgs, shrun, ... }:

{
  environment.systemPackages = [
    shrun
  ];
}
```
