export interface processFilesRequest {
    isValid?: boolean;
    audio: string[]
    video: string[]
}

export interface singleProcessOptions {
    videoPath: string,
    audioPath: string,
    output: string
}