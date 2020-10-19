export interface FileInfo {
    path: string
    size: number
    type: string
}

export interface ProcessFilesRequest {
    isValid: boolean
    numVideos: number
    audioList: FileInfo[]
    videoList: FileInfo[]
    unrecognized: FileInfo[]
}

export interface SingleProcessOptions {
    video: FileInfo
    audio: FileInfo
    output: string
    bytes: number
}

export interface ProcessResult {
    processed: number
    total: number
    errors: string[]
}