interface ffmpegInput {
    isValid?: boolean;
    audio: string[]
    video: string[]
}

interface singleProcessOptions {
    videoPath: string,
    audioPath: string,
    output: string
}

export { ffmpegInput, singleProcessOptions }