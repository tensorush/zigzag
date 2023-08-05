## :lizard: :trident: **zigzag**

[![CI][ci-shield]][ci-url]
[![License][license-shield]][license-url]

### Multi-threaded CPU path tracer.

#### :rocket: Usage

1. Add `zigzag` as a dependency in your `build.zig.zon`.

    <details>

    <summary><code>build.zig.zon</code> example</summary>

    ```zig
    .{
        .name = "<name_of_your_package>",
        .version = "<version_of_your_package>",
        .dependencies = .{
            .zigzag = .{
                .url = "https://github.com/tensorush/zigzag/archive/<git_tag_or_commit_hash>.tar.gz",
                .hash = "<package_hash>",
            },
        },
    }
    ```

    Set `<package_hash>` to `12200000000000000000000000000000000000000000000000000000000000000000`, and Zig will provide the correct found value in an error message.

    </details>

2. Add `zigzag` as a run artifact in your `build.zig`.

    <details>

    <summary><code>build.zig</code> example</summary>

    ```zig
    const zigzag = b.dependency("zigzag", .{});
    const zigzag_run = b.addRunArtifact(zigzag.artifact("exe"));
    if (b.args) |args| {
        zigzag_run.addArgs(args);
    }
    ```

    </details>

#### :framed_picture: Render

<h4 align="center">
    <p>1024x1024 pixels with 256 samples per pixel and 8x SSAA</p>
</h4>

<p align="center">
    <img src="renders/render.png">
</p>

<!-- MARKDOWN LINKS -->

[ci-shield]: https://img.shields.io/github/actions/workflow/status/tensorush/zigzag/ci.yaml?branch=main&style=for-the-badge&logo=github&label=CI&labelColor=black
[ci-url]: https://github.com/tensorush/zigzag/blob/main/.github/workflows/ci.yaml
[license-shield]: https://img.shields.io/github/license/tensorush/zigzag.svg?style=for-the-badge&labelColor=black
[license-url]: https://github.com/tensorush/zigzag/blob/main/LICENSE.md
