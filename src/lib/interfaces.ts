export interface FileInfo {
    path: string
    size: number
}

export interface ProcessFilesRequest {
    isValid: boolean
    numVideos: number
    audioList: FileInfo[]
    videoList: FileInfo[]
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