export interface ProcessFilesRequest {
    isValid: boolean
    numVideos: number
    audio: string[]
    video: string[]
}

export interface SingleProcessOptions {
    videoPath: string
    audioPath: string
    output: string
}

export interface ProcessResult {
    processed: number
    total: number
}