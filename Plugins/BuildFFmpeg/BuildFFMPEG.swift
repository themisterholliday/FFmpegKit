//
//  BuildFFMPEG.swift
//
//
//  Created by kintan on 12/26/23.
//

import Foundation

class BuildFFMPEG: BaseBuild {
    init() {
        super.init(library: .FFmpeg)
        if Utility.shell("which nasm") == nil {
            Utility.shell("brew install nasm")
        }
        if Utility.shell("which sdl2-config") == nil {
            Utility.shell("brew install sdl2")
        }
        let lldbFile = URL.currentDirectory + "LLDBInitFile"
        try? FileManager.default.removeItem(at: lldbFile)
        FileManager.default.createFile(atPath: lldbFile.path, contents: nil, attributes: nil)
        let path = directoryURL + "libavcodec/videotoolbox.c"
        if let data = FileManager.default.contents(atPath: path.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: "kCVPixelBufferOpenGLESCompatibilityKey", with: "kCVPixelBufferMetalCompatibilityKey")
            str = str.replacingOccurrences(of: "kCVPixelBufferIOSurfaceOpenGLTextureCompatibilityKey", with: "kCVPixelBufferMetalCompatibilityKey")
            try! str.write(toFile: path.path, atomically: true, encoding: .utf8)
        }
    }

    override func flagsDependencelibrarys() -> [Library] {
        [.gmp, .nettle, .gnutls, .libsmbclient]
    }

    override func frameworks() throws -> [String] {
        var frameworks: [String] = []
        if let platform = platforms().first {
            if let arch = platform.architectures.first {
                let lib = thinDir(platform: platform, arch: arch) + "lib"
                let fileNames = try FileManager.default.contentsOfDirectory(atPath: lib.path)
                for fileName in fileNames {
                    if fileName.hasPrefix("lib"), fileName.hasSuffix(".a") {
                        // 因为其他库也可能引入libavformat,所以把lib改成大写，这样就可以排在前面，覆盖别的库。
                        frameworks.append("Lib" + fileName.dropFirst(3).dropLast(2))
                    }
                }
            }
        }
        return frameworks
    }

    override func ldFlags(platform: PlatformType, arch: ArchType) -> [String] {
        var ldFlags = super.ldFlags(platform: platform, arch: arch)
        ldFlags.append("-lc++")
        return ldFlags
    }

    override func environment(platform: PlatformType, arch: ArchType) -> [String: String] {
        var env = super.environment(platform: platform, arch: arch)
        env["CPPFLAGS"] = env["CFLAGS"]
        return env
    }

    override func build(platform: PlatformType, arch: ArchType, buildURL: URL) throws {
        try super.build(platform: platform, arch: arch, buildURL: buildURL)
        let prefix = thinDir(platform: platform, arch: arch)
        let lldbFile = URL.currentDirectory + "LLDBInitFile"
        if let data = FileManager.default.contents(atPath: lldbFile.path), var str = String(data: data, encoding: .utf8) {
            str.append("settings \(str.isEmpty ? "set" : "append") target.source-map \((buildURL + "src").path) \(directoryURL.path)\n")
            try str.write(toFile: lldbFile.path, atomically: true, encoding: .utf8)
        }
        try FileManager.default.copyItem(at: buildURL + "config.h", to: prefix + "include/libavutil/config.h")
        try FileManager.default.copyItem(at: buildURL + "config.h", to: prefix + "include/libavcodec/config.h")
        try FileManager.default.copyItem(at: buildURL + "config.h", to: prefix + "include/libavformat/config.h")
        try FileManager.default.copyItem(at: buildURL + "src/libavutil/getenv_utf8.h", to: prefix + "include/libavutil/getenv_utf8.h")
        try FileManager.default.copyItem(at: buildURL + "src/libavutil/libm.h", to: prefix + "include/libavutil/libm.h")
        try FileManager.default.copyItem(at: buildURL + "src/libavutil/thread.h", to: prefix + "include/libavutil/thread.h")
        try FileManager.default.copyItem(at: buildURL + "src/libavutil/intmath.h", to: prefix + "include/libavutil/intmath.h")
        try FileManager.default.copyItem(at: buildURL + "src/libavutil/mem_internal.h", to: prefix + "include/libavutil/mem_internal.h")
        try FileManager.default.copyItem(at: buildURL + "src/libavutil/attributes_internal.h", to: prefix + "include/libavutil/attributes_internal.h")
        try FileManager.default.copyItem(at: buildURL + "src/libavcodec/mathops.h", to: prefix + "include/libavcodec/mathops.h")
        try FileManager.default.copyItem(at: buildURL + "src/libavformat/os_support.h", to: prefix + "include/libavformat/os_support.h")
        let internalPath = prefix + "include/libavutil/internal.h"
        try FileManager.default.copyItem(at: buildURL + "src/libavutil/internal.h", to: internalPath)
        if let data = FileManager.default.contents(atPath: internalPath.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: """
            #include "timer.h"
            """, with: """
            // #include "timer.h"
            """)
            str = str.replacingOccurrences(of: "kCVPixelBufferIOSurfaceOpenGLTextureCompatibilityKey", with: "kCVPixelBufferMetalCompatibilityKey")
            try str.write(toFile: internalPath.path, atomically: true, encoding: .utf8)
        }
        if platform == .macos, arch.executable {
            let fftoolsFile = URL.currentDirectory + "../Sources/fftools"
            try? FileManager.default.removeItem(at: fftoolsFile)
            if !FileManager.default.fileExists(atPath: (fftoolsFile + "include/compat").path) {
                try FileManager.default.createDirectory(at: fftoolsFile + "include/compat", withIntermediateDirectories: true)
            }
            try FileManager.default.copyItem(at: buildURL + "src/compat/va_copy.h", to: fftoolsFile + "include/compat/va_copy.h")
            try FileManager.default.copyItem(at: buildURL + "config.h", to: fftoolsFile + "include/config.h")
            try FileManager.default.copyItem(at: buildURL + "config_components.h", to: fftoolsFile + "include/config_components.h")
            if !FileManager.default.fileExists(atPath: (fftoolsFile + "include/libavdevice").path) {
                try FileManager.default.createDirectory(at: fftoolsFile + "include/libavdevice", withIntermediateDirectories: true)
            }
            try FileManager.default.copyItem(at: buildURL + "src/libavdevice/avdevice.h", to: fftoolsFile + "include/libavdevice/avdevice.h")
            try FileManager.default.copyItem(at: buildURL + "src/libavdevice/version_major.h", to: fftoolsFile + "include/libavdevice/version_major.h")
            try FileManager.default.copyItem(at: buildURL + "src/libavdevice/version.h", to: fftoolsFile + "include/libavdevice/version.h")
            if !FileManager.default.fileExists(atPath: (fftoolsFile + "include/libpostproc").path) {
                try FileManager.default.createDirectory(at: fftoolsFile + "include/libpostproc", withIntermediateDirectories: true)
            }
            try FileManager.default.copyItem(at: buildURL + "src/libpostproc/postprocess_internal.h", to: fftoolsFile + "include/libpostproc/postprocess_internal.h")
            try FileManager.default.copyItem(at: buildURL + "src/libpostproc/postprocess.h", to: fftoolsFile + "include/libpostproc/postprocess.h")
            try FileManager.default.copyItem(at: buildURL + "src/libpostproc/version_major.h", to: fftoolsFile + "include/libpostproc/version_major.h")
            try FileManager.default.copyItem(at: buildURL + "src/libpostproc/version.h", to: fftoolsFile + "include/libpostproc/version.h")
            let ffplayFile = URL.currentDirectory + "../Sources/ffplay"
            try? FileManager.default.removeItem(at: ffplayFile)
            try FileManager.default.createDirectory(at: ffplayFile, withIntermediateDirectories: true)
            let ffprobeFile = URL.currentDirectory + "../Sources/ffprobe"
            try? FileManager.default.removeItem(at: ffprobeFile)
            try FileManager.default.createDirectory(at: ffprobeFile, withIntermediateDirectories: true)
            let ffmpegFile = URL.currentDirectory + "../Sources/ffmpeg"
            try? FileManager.default.removeItem(at: ffmpegFile)
            try FileManager.default.createDirectory(at: ffmpegFile + "include", withIntermediateDirectories: true)
            let fftools = buildURL + "src/fftools"
            let fileNames = try FileManager.default.contentsOfDirectory(atPath: fftools.path)
            for fileName in fileNames {
                if fileName.hasPrefix("ffplay") {
                    try FileManager.default.copyItem(at: fftools + fileName, to: ffplayFile + fileName)
                } else if fileName.hasPrefix("ffprobe") {
                    try FileManager.default.copyItem(at: fftools + fileName, to: ffprobeFile + fileName)
                } else if fileName.hasPrefix("ffmpeg") {
                    if fileName.hasSuffix(".h") {
                        try FileManager.default.copyItem(at: fftools + fileName, to: ffmpegFile + "include" + fileName)
                    } else {
                        try FileManager.default.copyItem(at: fftools + fileName, to: ffmpegFile + fileName)
                    }
                } else if fileName.hasSuffix(".h") {
                    try FileManager.default.copyItem(at: fftools + fileName, to: fftoolsFile + "include" + fileName)
                } else if fileName.hasSuffix(".c") {
                    try FileManager.default.copyItem(at: fftools + fileName, to: fftoolsFile + fileName)
                }
            }
            let prefix = scratch(platform: platform, arch: arch)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: "/usr/local/bin/ffmpeg"))
            try? FileManager.default.copyItem(at: prefix + "ffmpeg", to: URL(fileURLWithPath: "/usr/local/bin/ffmpeg"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: "/usr/local/bin/ffplay"))
            try? FileManager.default.copyItem(at: prefix + "ffplay", to: URL(fileURLWithPath: "/usr/local/bin/ffplay"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: "/usr/local/bin/ffprobe"))
            try? FileManager.default.copyItem(at: prefix + "ffprobe", to: URL(fileURLWithPath: "/usr/local/bin/ffprobe"))
        }
    }

    override func frameworkExcludeHeaders(_ framework: String) -> [String] {
        if framework == "Libavcodec" {
            return ["xvmc", "vdpau", "qsv", "dxva2", "d3d11va", "mathops", "videotoolbox"]
        } else if framework == "Libavutil" {
            return ["hwcontext_vulkan", "hwcontext_vdpau", "hwcontext_vaapi", "hwcontext_qsv", "hwcontext_opencl", "hwcontext_dxva2", "hwcontext_d3d11va", "hwcontext_cuda", "hwcontext_videotoolbox", "getenv_utf8", "intmath", "libm", "thread", "mem_internal", "internal", "attributes_internal"]
        } else if framework == "Libavformat" {
            return ["os_support"]
        } else {
            return super.frameworkExcludeHeaders(framework)
        }
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        var arguments = [
            "--prefix=\(thinDir(platform: platform, arch: arch).path)",
        ]
        // Plex Patch so we can have the `Codec` type
        for item in ffmpegConfiguers {
            if let item = item as? String {
                arguments += [item]
            }
            if let item = item as? Codec {
                arguments += item.flags
            }
        }
        arguments += Build.ffmpegConfiguers
        arguments.append("--arch=\(arch.cpuFamily)")
        if platform == .android {
            arguments.append("--target-os=android")
            // 这些参数apple不加也可以编译通过，android一定要加
            arguments.append("--cc=\(platform.cc)")
            arguments.append("--cxx=\(platform.cc)++")
//            arguments.append("--cross-prefix=\(platform.host(arch: arch))-")
//            arguments.append("--sysroot=\(platform.isysroot)")
        } else {
            arguments.append("--target-os=darwin")
            arguments.append("--enable-libxml2")
        }
        // arguments.append(arch.cpu())
        /**
         aacpsdsp.o), building for Mac Catalyst, but linking in object file built for
         x86_64 binaries are built without ASM support, since ASM for x86_64 is actually x86 and that confuses `xcodebuild -create-xcframework` https://stackoverflow.com/questions/58796267/building-for-macos-but-linking-in-object-file-built-for-free-standing/59103419#59103419
         */
        if platform == .maccatalyst || arch == .x86_64 {
            arguments.append("--disable-neon")
            arguments.append("--disable-asm")
        } else {
            arguments.append("--enable-neon")
            arguments.append("--enable-asm")
        }
        if ![.watchsimulator, .watchos, .android].contains(platform) {
            arguments.append("--enable-videotoolbox")
            arguments.append("--enable-audiotoolbox")
            arguments.append("--enable-filter=yadif_videotoolbox")
            arguments.append("--enable-filter=scale_vt")
            arguments.append("--enable-filter=transpose_vt")
        } else {
            arguments.append("--enable-encoder=h264_videotoolbox")
            arguments.append("--enable-encoder=mpeg4_videotoolbox")
            arguments.append("--enable-encoder=hevc_videotoolbox")
            arguments.append("--enable-encoder=prores_videotoolbox")
        }
        if platform == .macos, arch.executable {
            arguments.append("--enable-ffplay")
            arguments.append("--enable-sdl2")
            arguments.append("--enable-decoder=rawvideo")
            arguments.append("--enable-filter=color")
            arguments.append("--enable-filter=lut")
            arguments.append("--enable-filter=testsrc")
            // debug
            arguments.append("--enable-debug")
            arguments.append("--enable-debug=3")
            arguments.append("--disable-stripping")
        } else {
            arguments.append("--disable-programs")
        }
        if platform == .macos {
            arguments.append("--enable-outdev=audiotoolbox")
        }
        if !([PlatformType.tvos, .tvsimulator, .xros, .xrsimulator].contains(platform)) {
            // tvos17才支持AVCaptureDeviceInput
//            'defaultDeviceWithMediaType:' is unavailable: not available on visionOS
            arguments.append("--enable-indev=avfoundation")
        }
        //        if platform == .isimulator || platform == .tvsimulator {
        //            arguments.append("--assert-level=1")
        //        }
        for library in Library.allCases {
            let path = URL.currentDirectory + [library.rawValue, platform.rawValue, "thin", arch.rawValue]
            if FileManager.default.fileExists(atPath: path.path), library.isFFmpegDependentLibrary {
                arguments.append("--enable-\(library.rawValue)")
                if library == .libsrt || library == .libsmbclient {
                    arguments.append("--enable-protocol=\(library.rawValue)")
                } else if library == .libdav1d {
                    arguments.append("--enable-decoder=\(library.rawValue)")
                } else if library == .libass {
                    arguments.append("--enable-filter=ass")
                    arguments.append("--enable-filter=subtitles")
                } else if library == .libzvbi {
                    arguments.append("--enable-decoder=libzvbi_teletext")
                } else if library == .libplacebo {
                    arguments.append("--enable-filter=libplacebo")
                }
            }
        }
        return arguments
    }

    /*
     boxblur_filter_deps="gpl"
     delogo_filter_deps="gpl"
     */
    private let ffmpegConfiguers: [Any] = [
        // Configuration options:
        "--disable-armv5te", "--disable-armv6", "--disable-armv6t2",
        "--disable-bzlib", "--disable-gray", "--disable-iconv", "--disable-linux-perf",
        "--disable-shared", "--disable-small", "--disable-swscale-alpha", "--disable-symver", "--disable-xlib",
        "--enable-cross-compile",
        "--enable-optimizations", "--enable-pic", "--enable-runtime-cpudetect", "--enable-static", "--enable-thumb", "--enable-version3",
        "--pkg-config-flags=--static",
        // Documentation options:
        "--disable-doc", "--disable-htmlpages", "--disable-manpages", "--disable-podpages", "--disable-txtpages",
        // Component options:
        "--enable-avcodec", "--enable-avformat", "--enable-avutil", "--enable-network", "--enable-swresample", "--enable-swscale",
        "--disable-devices", "--disable-outdevs", "--disable-indevs", "--disable-postproc",
        "--enable-indev=lavfi",
        // ,"--disable-pthreads"
        // ,"--disable-w32threads"
        // ,"--disable-os2threads"
        // ,"--disable-dct"
        // ,"--disable-dwt"
        // ,"--disable-lsp"
        // ,"--disable-lzo"
        // ,"--disable-mdct"
        // ,"--disable-rdft"
        // ,"--disable-fft"
        // Hardware accelerators:
        "--disable-d3d11va", "--disable-dxva2", "--disable-vaapi", "--disable-vdpau",
        // todo ffmpeg的编译脚本有问题，没有加入libavcodec/vulkan_video_codec_av1std.h
        "--disable-hwaccel=av1_vulkan,hevc_vulkan,h264_vulkan",
        // Individual component options:
        // ,"--disable-everything"
        // ./configure --list-muxers
        "--disable-muxers",
        "--enable-muxer=flac", "--enable-muxer=dash", "--enable-muxer=hevc",
        "--enable-muxer=m4v", "--enable-muxer=matroska", "--enable-muxer=mov", "--enable-muxer=mp4",
        "--enable-muxer=mpegts", "--enable-muxer=webm*",
        "--enable-muxer=nut",
        // ./configure --list-encoders
        "--disable-encoders",
        "--enable-encoder=aac", "--enable-encoder=alac", "--enable-encoder=flac", "--enable-encoder=pcm*",
        "--enable-encoder=movtext", "--enable-encoder=mpeg4", "--enable-encoder=prores",
        // ./configure --list-protocols
        "--enable-protocols",
        // ./configure --list-demuxers
        // 用所有的demuxers的话，那avformat就会达到8MB了，指定的话，那就只要4MB。
        "--disable-demuxers",
        "--enable-demuxer=aac", "--enable-demuxer=ac3", "--enable-demuxer=aiff", "--enable-demuxer=amr",
        "--enable-demuxer=ape", "--enable-demuxer=asf", "--enable-demuxer=ass", "--enable-demuxer=av1",
        "--enable-demuxer=avi", "--enable-demuxer=caf", "--enable-demuxer=concat",
        "--enable-demuxer=dash", "--enable-demuxer=data", "--enable-demuxer=dv",
        "--enable-demuxer=eac3",
        "--enable-demuxer=flac", "--enable-demuxer=flv", "--enable-demuxer=h264", "--enable-demuxer=hevc",
        "--enable-demuxer=hls", "--enable-demuxer=live_flv", "--enable-demuxer=loas", "--enable-demuxer=m4v",
        // matroska=mkv,mka,mks,mk3d
        "--enable-demuxer=matroska", "--enable-demuxer=mov", "--enable-demuxer=mp3", "--enable-demuxer=mpeg*",
        "--enable-demuxer=nut",
        "--enable-demuxer=ogg", "--enable-demuxer=rm", "--enable-demuxer=rtsp", "--enable-demuxer=rtp", "--enable-demuxer=srt",
        "--enable-demuxer=vc1", "--enable-demuxer=wav", "--enable-demuxer=webm_dash_manifest",
        // ./configure --list-bsfs
        "--enable-bsfs",
        // ./configure --list-decoders
        // 用所有的decoders的话，那avcodec就会达到40MB了，指定的话，那就只要20MB。
        "--disable-decoders",
        // 视频 Video
        // "--enable-decoder=av1", "--enable-decoder=dca", "--enable-decoder=dxv",
        // "--enable-decoder=ffv1", "--enable-decoder=ffvhuff", "--enable-decoder=flv",
        // "--enable-decoder=h263", "--enable-decoder=h263i", "--enable-decoder=h263p", "--enable-decoder=h264",
        // "--enable-decoder=hap", "--enable-decoder=hevc", "--enable-decoder=huffyuv",
        // "--enable-decoder=indeo5",
        // "--enable-decoder=mjpeg", "--enable-decoder=mjpegb", "--enable-decoder=mpeg*", "--enable-decoder=mts2",
        // "--enable-decoder=prores",
        // "--enable-decoder=rv10", "--enable-decoder=rv20", "--enable-decoder=rv30", "--enable-decoder=rv40",
        // "--enable-decoder=snow", "--enable-decoder=svq3",
        // "--enable-decoder=tscc", "--enable-decoder=tscc2", "--enable-decoder=txd",
        // "--enable-decoder=wmv1", "--enable-decoder=wmv2", "--enable-decoder=wmv3",
        // "--enable-decoder=vc1", "--enable-decoder=vp6", "--enable-decoder=vp6a", "--enable-decoder=vp6f",
        // "--enable-decoder=vp7", "--enable-decoder=vp8", "--enable-decoder=vp9",
        // 音频 Audio
        // "--enable-decoder=aac*", "--enable-decoder=ac3*", "--enable-decoder=adpcm*", "--enable-decoder=alac*",
        // "--enable-decoder=amr*", "--enable-decoder=ape", "--enable-decoder=cook",
        // "--enable-decoder=dca", "--enable-decoder=dolby_e", "--enable-decoder=eac3*", "--enable-decoder=flac",
        // "--enable-decoder=mp1*", "--enable-decoder=mp2*", "--enable-decoder=mp3*", "--enable-decoder=opus",
        // "--enable-decoder=pcm*", "--enable-decoder=sonic",
        // "--enable-decoder=truehd", "--enable-decoder=tta", "--enable-decoder=vorbis", "--enable-decoder=wma*", "--enable-decoder=wrapped_avframe",

        // 字幕 Subtitles
        // "--enable-decoder=ass", "--enable-decoder=ccaption", "--enable-decoder=dvbsub", "--enable-decoder=dvdsub",
        // "--enable-decoder=mpl2", "--enable-decoder=movtext",
        // "--enable-decoder=pgssub", "--enable-decoder=srt", "--enable-decoder=ssa", "--enable-decoder=subrip",
        // "--enable-decoder=xsub", "--enable-decoder=webvtt",

        // Plex Patch for only the decoders we need for Apple
        // Matching decoders: https://github.com/plexinc/plex-conan/blob/f4abeaf13fafe4ba873cdeeef30a1522a3390566/packages/ffmpeg/avcodec.py#L108

        // Primary video
        Codec("h264"),
        Codec("hevc"),
        Codec("vc1"),
        Codec("vc1image"),
        Codec("mpeg1video"),
        Codec("mpeg2video"),
        Codec("mpeg4"),
        Codec("msmpeg4v1"),
        Codec("msmpeg4v2"),
        Codec("msmpeg4v3", "msmpeg4v3", "msmpeg4"),

        // Primary audio
        Codec("aac"),
        Codec("aac_latm"),
        Codec("dca"),
        Codec("mp3"),
        Codec("ac3"),

        // Dolby patented codecs - we aren"t allowed to use them.
        // Codec("truehd"),
        // Codec("mlp"), // Basically TrueHD

        // Free video
        Codec("png"),      // PNG (Portable Network Graphics) image
        Codec("apng"),     // APNG (Animated Portable Network Graphics) image
        Codec("bmp"),      // BMP (Windows and OS/2 bitmap)
        Codec("mjpeg"),    // MJPEG (Motion JPEG)
        Codec("thp"),      // Nintendo Gamecube THP video (rcombs note: minor MJPEG variant)
        Codec("gif"),      // GIF (Graphics Interchange Format)
        Codec("vp8"),      // On2 VP8
        Codec("vp9"),      // Google VP9
        Codec("webp"),     // WebP image
        Codec("dirac"),    // BBC Dirac
        Codec("ffv1"),     // FFmpeg video codec  //1
        Codec("ffvhuff"),  // Huffyuv FFmpeg variant
        Codec("huffyuv"),  // Huffyuv / HuffYUV
        Codec("libdav1d", "av1"),
        Codec("av1"),

        // Uncompressed/raw video
        Codec("rawvideo"), // raw video
        Codec("zero12v", "012v"), // Uncompressed 4:2:2 10-bit
        Codec("ayuv"),     // Uncompressed packed MS 4:4:4:4
        Codec("r210"),     // Uncompressed RGB 10-bit
        Codec("v210"),     // Uncompressed 4:2:2 10-bit
        Codec("v210x"),    // Uncompressed 4:2:2 10-bit
        Codec("v308"),     // Uncompressed packed 4:4:4
        Codec("v408"),     // Uncompressed packed QT 4:4:4:4
        Codec("v410"),     // Uncompressed 4:4:4 10-bit
        Codec("y41p"),     // Uncompressed YUV 4:1:1 12-bit
        Codec("yuv4"),     // Uncompressed packed 4:2:0
        Codec("ansi"),     // ASCII/ANSI art

        // Free audio
        Codec("alac"),     // ALAC (Apple Lossless Audio Codec)
        Codec("flac"),     // FLAC (Free Lossless Audio Codec)
        Codec("vorbis"),   // VorbisAsao
        Codec("opus"),     // Opus

        // PCM
        Codec("pcm_f32be"),// PCM 32-bit floating point big-endian
        Codec("pcm_f32le"),// PCM 32-bit floating point little-endian
        Codec("pcm_f64be"),// PCM 64-bit floating point big-endian
        Codec("pcm_f64le"),// PCM 64-bit floating point little-endian
        Codec("pcm_lxf"),  // PCM signed 20-bit little-endian planar
        Codec("pcm_s16be"),// PCM signed 16-bit big-endian
        Codec("pcm_s16be_planar"),// PCM signed 16-bit big-endian planar
        Codec("pcm_s16le"),// PCM signed 16-bit little-endian
        Codec("pcm_s16le_planar"),// PCM signed 16-bit little-endian planar
        Codec("pcm_s24be"),// PCM signed 24-bit big-endian
        Codec("pcm_s24le"),// PCM signed 24-bit little-endian
        Codec("pcm_s24le_planar"),// PCM signed 24-bit little-endian planar
        Codec("pcm_s32be"),// PCM signed 32-bit big-endian
        Codec("pcm_s32le"),// PCM signed 32-bit little-endian
        Codec("pcm_s32le_planar"),// PCM signed 32-bit little-endian planar
        Codec("pcm_s8"),   // PCM signed 8-bit
        Codec("pcm_s8_planar"), // PCM signed 8-bit planar
        Codec("pcm_u16be"),// PCM unsigned 16-bit big-endian
        Codec("pcm_u16le"),// PCM unsigned 16-bit little-endian
        Codec("pcm_u24be"),// PCM unsigned 24-bit big-endian
        Codec("pcm_u24le"),// PCM unsigned 24-bit little-endian
        Codec("pcm_u32be"),// PCM unsigned 32-bit big-endian
        Codec("pcm_u32le"),// PCM unsigned 32-bit little-endian
        Codec("pcm_u8"),   // PCM unsigned 8-bit
        Codec("pcm_alaw"), // PCM A-law / G.711 A-law
        Codec("pcm_mulaw"),// PCM mu-law / G.711 mu-law

        // Subtitles
        Codec("ass"),      // ASS (Advanced SubStation Alpha) subtitle
        Codec("dvbsub", "dvb_subtitle"),   // DVB subtitles (codec dvb_subtitle)
        Codec("dvdsub", "vobsub"),   // DVD subtitles (codec dvd_subtitle)
        Codec("ccaption", "eia_608", "cc_dec"),   // Closed Caption (EIA-608 / CEA-708) Decoder (codec eia_608)
        Codec("pgssub", "pgs"),   // HDMV Presentation Graphic Stream subtitles (codec hdmv_pgs_subtitle)
        Codec("jacosub"),  // JACOsub subtitle
        Codec("microdvd"), // MicroDVD subtitle
        Codec("movtext", "mov_text", "mov_text"), // 3GPP Timed Text subtitle
        Codec("mpl2"),     // MPL2 subtitle
        Codec("pjs"),      // PJS subtitle
        Codec("realtext"), // RealText subtitle
        Codec("sami"),     // SAMI subtitle
        Codec("ssa"),      // SSA (SubStation Alpha) subtitle
        Codec("stl"),      // Spruce subtitle format
        Codec("subrip", "srt"),   // SubRip subtitle
        Codec("subviewer"),// SubViewer subtitle
        Codec("subviewer1"),                 // SubViewer1 subtitle
        Codec("text"),     // Raw text subtitle
        Codec("vplayer"),  // VPlayer subtitle
        Codec("webvtt"),   // WebVTT subtitle
        Codec("xsub"),     // XSUB

        // Long-tail video
        Codec("fourxm", "4xm"),              // 4X Movie
        Codec("eightbps", "8bps"),           // QuickTime 8BPS video
        Codec("aasc"),                       // Autodesk RLE
        Codec("aic"),                        // Apple Intermediate Codec
        Codec("alias_pix"),                  // Alias/Wavefront PIX image
        Codec("amv"),                        // AMV Video
        Codec("anm"),                        // Deluxe Paint Animation
        Codec("asv1"),                       // ASUS V1
        Codec("asv2"),                       // ASUS V2
        Codec("aura"),                       // Auravision AURA
        Codec("aura2"),                      // Auravision Aura 2
        Codec("avrn"),                       // Avid AVI Codec
        Codec("avrp"),                       // Avid 1:1 10-bit RGB Packer
        Codec("avs"),                        // AVS (Audio Video Standard) video
        Codec("avui"),                       // Avid Meridien Uncompressed
        Codec("bethsoftvid"),                // Bethesda VID video
        Codec("bfi"),                        // Brute Force & Ignorance
        Codec("bink", "binkvideo"),          // Bink video
        Codec("bintext"),                    // Binary text
        Codec("bmv_video"),                  // Discworld II BMV video
        Codec("brender_pix"),                // BRender PIX image
        Codec("c93"),                        // Interplay C93
        Codec("cavs"),                       // Chinese AVS (Audio Video Standard) (AVS1-P2, JiZhun profile)
        Codec("cdgraphics"),                 // CD Graphics video
        Codec("cdxl"),                       // Commodore CDXL video
        Codec("cfhd"),                       // CineForm HD
        Codec("cinepak"),                    // Cinepak
        Codec("cljr"),                       // Cirrus Logic AccuPak
        Codec("cllc"),                       // Canopus Lossless Codec
        Codec("eacmv", "cmv"),               // Electronic Arts CMV video (codec cmv)
        Codec("cpia"),                       // CPiA video format
        Codec("cscd"),                       // CamStudio
        Codec("cyuv"),                       // Creative YUV (CYUV)
        Codec("dds"),                        // DirectDraw Surface image decoder
        Codec("dfa"),                        // Chronomaster DFA
        Codec("dnxhd"),                      // VC3/DNxHD
        Codec("dpx"),                        // DPX (Digital Picture Exchange) image
        Codec("dsicinvideo"),                // Delphine Software International CIN video
        Codec("dvvideo"),                    // DV (Digital Video)
        Codec("dxa"),                        // Feeble Files/ScummVM DXA
        Codec("dxtory"),                     // Dxtory
        Codec("dxv"),                        // Resolume DXV
        Codec("escape124"),                  // Escape 124
        Codec("escape130"),                  // Escape 130
        Codec("exr"),                        // OpenEXR image
        Codec("fic"),                        // Mirillis FIC
        Codec("flashsv"),                    // Flash Screen Video v1
        Codec("flashsv2"),                   // Flash Screen Video v2
        Codec("flic"),                       // Autodesk Animator Flic video
        Codec("flv", "flv1"),                // FLV / Sorenson Spark / Sorenson H.263 (Flash Video) (codec flv1)
        Codec("fraps"),                      // Fraps
        Codec("frwu"),                       // Forward Uncompressed
        Codec("g2m"),                        // Go2Meeting
        Codec("h261"),                       // H.261
        Codec("h263"),                       // H.263 / H.263-1996, H.263+ / H.263-1998 / H.263 version 2
        Codec("h263i"),                      // Intel H.263
        Codec("h263p"),                      // H.263 / H.263-1996, H.263+ / H.263-1998 / H.263 version 2
        Codec("hap"),                        // Vidvox Hap decoder
        Codec("hnm4_video", "hnm4video"),    // HNM 4 video
        Codec("hq_hqa"),                     // Canopus HQ/HQA
        Codec("hqx"),                        // Canopus HQX
        Codec("idcin", "idcin", "idcinvideo"), // id Quake II CIN video (codec idcin)
        Codec("idf"),                        // iCEDraw text
        Codec("iff_ilbm", "iff_ilbm", "iff"), // IFF (codec iff_ilbm)
        Codec("indeo2"),                     // Intel Indeo 2
        Codec("indeo3"),                     // Intel Indeo 3
        Codec("indeo4"),                     // Intel Indeo Video Interactive 4
        Codec("indeo5"),                     // Intel Indeo Video Interactive 5
        Codec("interplay_video", "interplayvideo"), // Interplay MVE video
        Codec("jpeg2000"),                   // JPEG 2000
        Codec("jpegls"),                     // JPEG-LS
        Codec("jv"),                         // Bitmap Brothers JV video
        Codec("kgv1"),                       // Kega Game Video
        Codec("kmvc"),                       // Karl Morton"s video codec
        Codec("lagarith"),                   // Lagarith lossless
        Codec("loco"),                       // LOCO
        Codec("eamad", "mad"),               // Electronic Arts Madcow Video (codec mad)
        Codec("mdec"),                       // Sony PlayStation MDEC (Motion DECoder)
        Codec("mimic"),                      // Mimic
        Codec("mjpegb"),                     // Apple MJPEG-B
        Codec("mmvideo"),                    // American Laser Games MM Video
        Codec("motionpixels"),               // Motion Pixels video
        Codec("msa1"),                       // MS ATC Screen
        Codec("msrle"),                      // Microsoft RLE
        Codec("mss1"),                       // MS Screen 1
        Codec("mss2"),                       // MS Windows Media Video V9 Screen
        Codec("msvideo1"),                   // Microsoft Video 1
        Codec("mszh"),                       // LCL (LossLess Codec Library) MSZH
        Codec("mts2"),                       // MS Expression Encoder Screen
        Codec("mvc1"),                       // Silicon Graphics Motion Video Compressor 1
        Codec("mvc2"),                       // Silicon Graphics Motion Video Compressor 2
        Codec("mxpeg"),                      // Mobotix MxPEG video
        Codec("nuv"),                        // NuppelVideo/RTJPEG
        Codec("paf_video"),                  // Amazing Studio Packed Animation File Video
        Codec("pam"),                        // PAM (Portable AnyMap) image
        Codec("pbm"),                        // PBM (Portable BitMap) image
        Codec("pcx"),                        // PC Paintbrush PCX image
        Codec("pgm"),                        // PGM (Portable GrayMap) image
        Codec("pgmyuv"),                     // PGMYUV (Portable GrayMap YUV) image
        Codec("pictor"),                     // Pictor/PC Paint
        Codec("ppm"),                        // PPM (Portable PixelMap) image
        Codec("prores"),                     // ProRes
        Codec("ptx"),                        // V.Flash PTX image
        Codec("qdraw"),                      // Apple QuickDraw
        Codec("qpeg"),                       // Q-team QPEG
        Codec("qtrle"),                      // QuickTime Animation (RLE) video
        Codec("r10k"),                       // AJA Kona 10-bit RGB Codec
        Codec("rl2"),                        // RL2 video
        Codec("roq", "roq", "roqvideo"),     // id RoQ video (codec roq)
        Codec("rpza"),                       // QuickTime video (RPZA)
        Codec("rscc"),                       // innoHeim/Rsupport Screen Capture Codec
        Codec("rv10"),                       // RealVideo 1.0
        Codec("rv20"),                       // RealVideo 2.0
        Codec("rv30"),                       // RealVideo 3.0
        Codec("rv40"),                       // RealVideo 4.0
        Codec("sanm"),                       // LucasArts SANM/Smush video
        Codec("screenpresso"),               // Screenpresso
        Codec("sgi"),                        // SGI image
        Codec("sgirle"),                     // Silicon Graphics RLE 8-bit video
        Codec("smacker", "smackvideo", "smackvid"),      // Smacker video (codec smackvideo)
        Codec("smc"),                        // QuickTime Graphics (SMC)
        Codec("smvjpeg"),                    // SMV JPEG
        Codec("snow"),                       // Snow
        Codec("sp5x"),                       // Sunplus JPEG (SP5X)
        Codec("sunrast"),                    // Sun Rasterfile image
        Codec("svq1"),                       // Sorenson Vector Quantizer 1 / Sorenson Video 1 / SVQ1
        Codec("svq3"),                       // Sorenson Vector Quantizer 3 / Sorenson Video 3 / SVQ3
        Codec("targa"),                      // Truevision Targa image
        Codec("targa_y216"),                 // Pinnacle TARGA CineWave YUV16
        Codec("tdsc"),                       // TDSC
        Codec("eatgq", "tgq"),               // Electronic Arts TGQ video (codec tgq)
        Codec("eatgv", "tgv"),               // Electronic Arts TGV video (codec tgv)
        Codec("theora"),                     // Theora
        Codec("tiertexseqvideo"),            // Tiertex Limited SEQ video
        Codec("tiff"),                       // TIFF image
        Codec("tmv"),                        // 8088flex TMV
        Codec("eatqi", "tqi"),               // Electronic Arts TQI Video (codec tqi)
        Codec("truemotion1"),                // Duck TrueMotion 1.0
        Codec("truemotion2"),                // Duck TrueMotion 2.0
        Codec("truemotion2rt"),              // Duck TrueMotion 2.0 Real Time
        Codec("tscc", "tscc", "camtasia"),   // TechSmith Screen Capture Codec (codec tscc)
        Codec("tscc2"),                      // TechSmith Screen Codec 2
        Codec("txd"),                        // Renderware TXD (TeXture Dictionary) image
        Codec("ulti", "ulti", "ultimotion"), // IBM UltiMotion (codec ulti)
        Codec("utvideo"),                    // Ut Video
        Codec("vb"),                         // Beam Software VB
        Codec("vble"),                       // VBLE Lossless Codec
        Codec("vc1image"),                   // Windows Media Video 9 Image v2
        Codec("vcr1"),                       // ATI VCR1
        Codec("xl", "vixl"),                 // Miro VideoXL (codec vixl)
        Codec("vmdvideo"),                   // Sierra VMD video
        Codec("vmnc"),                       // VMware Screen Codec / VMware Video
        Codec("vp3"),                        // On2 VP3
        Codec("vp5"),                        // On2 VP5
        Codec("vp6"),                        // On2 VP6
        Codec("vp6a"),                       // On2 VP6 (Flash version, with alpha channel)
        Codec("vp6f"),                       // On2 VP6 (Flash version)
        Codec("vp7"),                        // On2 VP7
        Codec("wmv1"),                       // Windows Media Video 7
        Codec("wmv2"),                       // Windows Media Video 8
        Codec("wmv3"),                       // Windows Media Video 9
        Codec("wmv3image"),                  // Windows Media Video 9 Image
        Codec("wnv1"),                       // Winnov WNV1
        Codec("vqa", "ws_vqa", "vqavideo"),  // Westwood Studios VQA (Vector Quantized Animation) video (codec ws_vqa)
        Codec("xan_wc3"),                    // Wing Commander III / Xan
        Codec("xan_wc4"),                    // Wing Commander IV / Xxan
        Codec("xbin"),                       // eXtended BINary text
        Codec("xbm"),                        // XBM (X BitMap) image
        Codec("xface"),                      // X-face image
        Codec("xwd"),                        // XWD (X Window Dump) image
        Codec("yop"),                        // Psygnosis YOP Video
        Codec("zerocodec"),                  // ZeroCodec Lossless Video
        Codec("zlib"),                       // LCL (LossLess Codec Library) ZLIB
        Codec("zmbv"),                       // Zip Motion Blocks Video

        // Long-tail audio
        Codec("eightsvx_exp", "8svx_exp"),   // 8SVX exponential
        Codec("eightsvx_exp", "8svx_fib"),   // 8SVX fibonacci
        Codec("adpcm_4xm"),                  // ADPCM 4X Movie
        Codec("adpcm_adx"),                  // SEGA CRI ADX ADPCM
        Codec("adpcm_afc"),                  // ADPCM Nintendo Gamecube AFC
        Codec("adpcm_aica"),                 // ADPCM Yamaha AICA
        Codec("adpcm_ct"),                   // ADPCM Creative Technology
        Codec("adpcm_dtk"),                  // ADPCM Nintendo Gamecube DTK
        Codec("adpcm_ea"),                   // ADPCM Electronic Arts
        Codec("adpcm_ea_maxis_xa"),          // ADPCM Electronic Arts Maxis CDROM XA
        Codec("adpcm_ea_r1"),                // ADPCM Electronic Arts R1
        Codec("adpcm_ea_r2"),                // ADPCM Electronic Arts R2
        Codec("adpcm_ea_r3"),                // ADPCM Electronic Arts R3
        Codec("adpcm_ea_xas"),               // ADPCM Electronic Arts XAS
        Codec("adpcm_ima_dat4"),             // ADPCM IMA Eurocom DAT4
        Codec("adpcm_g722", "adpcm_g722", "g722"), // G.722 ADPCM (codec adpcm_g722)
        Codec("adpcm_g726", "adpcm_g726", "g726"), // G.726 ADPCM (codec adpcm_g726)
        Codec("adpcm_g726le", "adpcm_g726le", "g726le"), // G.726 ADPCM little-endian (codec adpcm_g726le)
        Codec("adpcm_ima_amv"),              // ADPCM IMA AMV
        Codec("adpcm_ima_apc"),              // ADPCM IMA CRYO APC
        Codec("adpcm_ima_dk3"),              // ADPCM IMA Duck DK3
        Codec("adpcm_ima_dk4"),              // ADPCM IMA Duck DK4
        Codec("adpcm_ima_ea_eacs"),          // ADPCM IMA Electronic Arts EACS
        Codec("adpcm_ima_ea_sead"),          // ADPCM IMA Electronic Arts SEAD
        Codec("adpcm_ima_iss"),              // ADPCM IMA Funcom ISS
        Codec("adpcm_ima_oki"),              // ADPCM IMA Dialogic OKI
        Codec("adpcm_ima_qt"),               // ADPCM IMA QuickTime
        Codec("adpcm_ima_rad"),              // ADPCM IMA Radical
        Codec("adpcm_ima_smjpeg"),           // ADPCM IMA Loki SDL MJPEG
        Codec("adpcm_ima_wav"),              // ADPCM IMA WAV
        Codec("adpcm_ima_ws"),               // ADPCM IMA Westwood
        Codec("adpcm_ms"),                   // ADPCM Microsoft
        Codec("adpcm_psx"),                  // ADPCM Playstation
        Codec("adpcm_sbpro_2"),              // ADPCM Sound Blaster Pro 2-bit
        Codec("adpcm_sbpro_3"),              // ADPCM Sound Blaster Pro 2.6-bit
        Codec("adpcm_sbpro_4"),              // ADPCM Sound Blaster Pro 4-bit
        Codec("adpcm_swf"),                  // ADPCM Shockwave Flash
        Codec("adpcm_thp"),                  // ADPCM Nintendo THP
        Codec("adpcm_thp_le"),               // ADPCM Nintendo THP (little-endian)
        Codec("adpcm_vima"),                 // LucasArts VIMA audio
        Codec("adpcm_xa"),                   // ADPCM CDROM XA
        Codec("adpcm_yamaha"),               // ADPCM Yamaha
        Codec("amrnb", "amr_nb"),            // AMR-NB (Adaptive Multi-Rate NarrowBand) (codec amr_nb)
        Codec("amrwb", "amr_wb"),            // AMR-WB (Adaptive Multi-Rate WideBand) (codec amr_wb)
        Codec("ape"),                        // Monkey"s Audio
        Codec("atrac1"),                     // ATRAC1 (Adaptive TRansform Acoustic Coding)
        Codec("atrac3"),                     // ATRAC3 (Adaptive TRansform Acoustic Coding 3)
        Codec("atrac3p", "atrac3p", "atrac3plus"), // ATRAC3+ (Adaptive TRansform Acoustic Coding 3+) (codec atrac3p)
        Codec("on2avc", "avc"),              // On2 Audio for Video Codec (codec avc)
        Codec("binkaudio_dct"),              // Bink Audio (DCT)
        Codec("binkaudio_rdft"),             // Bink Audio (RDFT)
        Codec("bmv_audio"),                  // Discworld II BMV audio
        Codec("comfortnoise"),               // RFC 3389 comfort noise generator
        Codec("cook"),                       // Cook / Cooker / Gecko (RealAudio G2)
        Codec("dsd_lsbf"),                   // DSD (Direct Stream Digital), least significant bit first
        Codec("dsd_lsbf_planar"),            // DSD (Direct Stream Digital), least significant bit first, planar
        Codec("dsd_msbf"),                   // DSD (Direct Stream Digital), most significant bit first
        Codec("dsd_msbf_planar"),            // DSD (Direct Stream Digital), most significant bit first, planar
        Codec("dsicinaudio"),                // Delphine Software International CIN audio
        Codec("dss_sp"),                     // Digital Speech Standard - Standard Play mode (DSS SP)
        Codec("dvaudio"),                    // Ulead DV Audio
        Codec("evrc"),                       // EVRC (Enhanced Variable Rate Codec)
        Codec("g723_1"),                     // G.723.1
        Codec("g729"),                       // G.729
        Codec("gsm"),                        // GSM
        Codec("gsm_ms"),                     // GSM Microsoft variant
        Codec("iac"),                        // IAC (Indeo Audio Coder)
        Codec("imc"),                        // IMC (Intel Music Coder)
        Codec("interplay_dpcm"),             // DPCM Interplay
        Codec("interplay_acm", "interplayacm"), // Interplay ACM
        Codec("mace3"),                      // MACE (Macintosh Audio Compression/Expansion) 3:1
        Codec("mace6"),                      // MACE (Macintosh Audio Compression/Expansion) 6:1
        Codec("metasound"),                  // Voxware MetaSound
        Codec("mp1"),                        // MP1 (MPEG audio layer 1)
        Codec("mp2"),                        // MP2 (MPEG audio layer 2)
        Codec("mp3adu"),                     // ADU (Application Data Unit) MP3 (MPEG audio layer 3)
        Codec("mp3on4"),                     // MP3onMP4
        Codec("als", "mp4als"),              // MPEG-4 Audio Lossless Coding (ALS) (codec mp4als)
        Codec("mpc7", "musepack7"),          // Musepack SV7 (codec musepack7)
        Codec("mpc8", "musepack8"),          // Musepack SV8 (codec musepack8)
        Codec("nellymoser"),                 // Nellymoser
        Codec("paf_audio"),                  // Amazing Studio Packed Animation File Audio
        Codec("pcm_bluray"),                 // PCM signed 16|20|24-bit big-endian for Blu-ray media
        Codec("pcm_dvd"),                    // PCM signed 16|20|24-bit big-endian for DVD media
        Codec("qcelp"),                      // QCELP / PureVoice
        Codec("qdm2"),                       // QDesign Music Codec 2
        Codec("ra_144", "ra_144", "real_144"), // RealAudio 1.0 (14.4K) (codec ra_144)
        Codec("ra_288", "ra_288", "real_288"), // RealAudio 2.0 (28.8K) (codec ra_288)
        Codec("ralf"),                       // RealAudio Lossless
        Codec("roq_dpcm"),                   // DPCM id RoQ
        Codec("s302m"),                      // SMPTE 302M
        Codec("sdx2_dpcm"),                  // DPCM Squareroot-Delta-Exact
        Codec("shorten"),                    // Shorten
        Codec("sipr"),                       // RealAudio SIPR / ACELP.NET
        Codec("smackaud", "smackaudio"),     // Smacker audio (codec smackaudio)
        Codec("sol_dpcm"),                   // DPCM Sol
        Codec("sonic"),                      // Sonic
        Codec("tak"),                        // TAK (Tom"s lossless Audio Kompressor)
        Codec("truespeech"),                 // DSP Group TrueSpeech
        Codec("tta"),                        // TTA (True Audio)
        Codec("twinvq"),                     // VQF TwinVQ
        Codec("vmdaudio"),                   // Sierra VMD audio
        Codec("ffwavesynth", "wavesynth"),   // Wave synthesis pseudo-codec
        Codec("wavpack"),                    // WavPack
        Codec("ws_snd1", "westwood_snd1"),   // Westwood Audio (SND1) (codec westwood_snd1)
        Codec("wmalossless"),                // Windows Media Audio Lossless
        Codec("wmapro"),                     // Windows Media Audio 9 Professional
        Codec("wmav1"),                      // Windows Media Audio 1
        Codec("wmav2"),                      // Windows Media Audio 2
        Codec("wmavoice"),                   // Windows Media Audio Voice
        Codec("xan_dpcm"),                   // DPCM Xan
        Codec("xma1"),                       // Xbox Media Audio 1
        Codec("xma2"),                       // Xbox Media Audio 2

        // On iOS we don"t have CoD so we enable all the AT ones.
        Codec("aac_at"),
        Codec("ac3_at"),
        Codec("alac_at"),  // ALAC (Apple Lossless Audio Codec)
        Codec("eac3_at"),
        Codec("mp1_at"),
        Codec("mp2_at"),
        Codec("mp3_at"),

        Codec("mp1"),
        Codec("mp2"),

        Codec("ass"),
        Codec("ayuv"),
        Codec("ccaption"),
        Codec("dvbsub"),
        Codec("dvdsub"),
        Codec("h263"),
        Codec("jacosub"),
        Codec("microdvd"),
        Codec("movtext"),
        Codec("pgssub"),
        Codec("pjs"),
        Codec("r210"),
        Codec("realtext"),
        Codec("sami"),
        Codec("ssa"),
        Codec("stl"),
        Codec("subrip"),
        Codec("subviewer"),
        Codec("subviewer1"),
        Codec("text"),
        Codec("vplayer"),
        Codec("webvtt"),
        Codec("xsub"),
        Codec("y41p"),
        Codec("yuv4"),
        Codec("zero12v"),

        // ./configure --list-filters
        "--disable-filters",
        "--enable-filter=aformat", "--enable-filter=amix", "--enable-filter=anull", "--enable-filter=aresample",
        "--enable-filter=areverse", "--enable-filter=asetrate", "--enable-filter=atempo", "--enable-filter=atrim",
        "--enable-filter=boxblur", "--enable-filter=bwdif", "--enable-filter=delogo",
        "--enable-filter=equalizer", "--enable-filter=estdif",
        "--enable-filter=firequalizer", "--enable-filter=format", "--enable-filter=fps",
        "--enable-filter=gblur",
        "--enable-filter=hflip", "--enable-filter=hwdownload", "--enable-filter=hwmap", "--enable-filter=hwupload",
        "--enable-filter=idet", "--enable-filter=lenscorrection", "--enable-filter=lut*", "--enable-filter=negate", "--enable-filter=null",
        "--enable-filter=overlay",
        "--enable-filter=palettegen", "--enable-filter=paletteuse", "--enable-filter=pan",
        "--enable-filter=rotate",
        "--enable-filter=scale", "--enable-filter=setpts", "--enable-filter=superequalizer",
        "--enable-filter=transpose", "--enable-filter=trim",
        "--enable-filter=vflip", "--enable-filter=volume",
        "--enable-filter=w3fdif",
        "--enable-filter=yadif",
        "--enable-filter=avgblur_vulkan", "--enable-filter=blend_vulkan", "--enable-filter=bwdif_vulkan",
        "--enable-filter=chromaber_vulkan", "--enable-filter=flip_vulkan", "--enable-filter=gblur_vulkan",
        "--enable-filter=hflip_vulkan", "--enable-filter=nlmeans_vulkan", "--enable-filter=overlay_vulkan",
        "--enable-filter=vflip_vulkan", "--enable-filter=xfade_vulkan",
    ]
}

class BuildZvbi: BaseBuild {
    init() {
        super.init(library: .libzvbi)
        let path = directoryURL + "configure.ac"
        if let data = FileManager.default.contents(atPath: path.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: "AC_FUNC_MALLOC", with: "")
            str = str.replacingOccurrences(of: "AC_FUNC_REALLOC", with: "")
            try! str.write(toFile: path.path, atomically: true, encoding: .utf8)
        }
    }

    override func platforms() -> [PlatformType] {
        super.platforms().filter {
            $0 != .maccatalyst
        }
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        ["--host=\(platform.host(arch: arch))",
         "--prefix=\(thinDir(platform: platform, arch: arch).path)"]
    }
}

class BuildSRT: BaseBuild {
    init() {
        super.init(library: .libsrt)
    }

    override func arguments(platform: PlatformType, arch _: ArchType) -> [String] {
        [
            "-Wno-dev",
//            "-DUSE_ENCLIB=openssl",
            "-DUSE_ENCLIB=gnutls",
            "-DENABLE_STDCXX_SYNC=1",
            "-DENABLE_CXX11=1",
            "-DUSE_OPENSSL_PC=1",
            "-DENABLE_DEBUG=0",
            "-DENABLE_LOGGING=0",
            "-DENABLE_HEAVY_LOGGING=0",
            "-DENABLE_APPS=0",
            "-DENABLE_SHARED=0",
            platform == .maccatalyst ? "-DENABLE_MONOTONIC_CLOCK=0" : "-DENABLE_MONOTONIC_CLOCK=1",
        ]
    }
}

class BuildFontconfig: BaseBuild {
    init() {
        super.init(library: .libfontconfig)
    }

    override func arguments(platform _: PlatformType, arch _: ArchType) -> [String] {
        [
            "-Ddoc=disabled",
            "-Dtests=disabled",
        ]
    }
}

class BuildBluray: BaseBuild {
    init() {
        super.init(library: .libbluray)
    }

    // 只有macos支持mount
    override func platforms() -> [PlatformType] {
        [.macos]
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        [
            "--disable-bdjava-jar",
            "--disable-silent-rules",
            "--disable-dependency-tracking",
            "--host=\(platform.host(arch: arch))",
            "--prefix=\(thinDir(platform: platform, arch: arch).path)",
        ]
    }
}

class Codec {
    var flags: [String] = []
    
    init(_ first: String, _ second: String? = nil, _ third: String? = nil) {
        flags.append("--enable-decoder=\(first)")
        if let second {
            flags.append("--enable-decoder=\(second)")
        }
        if let third {
            flags.append("--enable-decoder=\(third)")
        }
    }
}
