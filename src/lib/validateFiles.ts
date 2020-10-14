import { size } from 'lodash';
import { ProcessFilesRequest, FileInfo } from './interfaces';

const validateFiles = () => {
    function createRequest(files: FileInfo[]): ProcessFilesRequest {
        const result: ProcessFilesRequest = { 
            audioList: [], 
            videoList: [], 
            numVideos: 0,
            isValid: false
        }

        for(let i = 0; i < files.length; i++) {
            switch(files[i].type.toLowerCase()) {
                case 'audio/mpeg':
                case 'audio/mp4': 
                case 'audio/x-aiff': 
                case 'audio/vnd.wav': 
                case 'audio/vorbis': 
                case 'audio/wav': 
                case 'audio/wave': 
                case 'audio/webm':
                case 'audio/3gpp':
                case 'audio/aac':
                case 'audio/mp3':
                case 'audio/ogg':
                case 'audio/vnd.dts':
                case 'audio/x-aac':
                case 'audio/x-flac':
                case 'audio/x-m4a':
                case 'audio/x-matroska':
                case 'audio/x-ms-wma':
                case 'audio/x-wav':
                    result.audioList.push(files[i]);
                    break;
                case 'video/mp4':   
                case 'video/quicktime':    
                case 'video/h264':
                case 'video/h265':
                case 'video/webm':
                case 'video/x-matroska':
                case 'video/x-ms-wmv':
                case 'video/x-msvideo':
                case 'video/x-m4v':
                case 'video/x-flv':
                case 'video/x-f4v':
                case 'video/ogg':
                case 'video/mpeg':
                case 'video/mp2t':
                case 'video/3gpp':
                    result.videoList.push(files[i]);
                    break;
            }
        }

        return {
            ...result,
            isValid: !!result.audioList.length && !!result.videoList.length,
            numVideos: result.audioList.length * result.videoList.length,
        }
    }

    function createRequestFromFileList(files: FileList): ProcessFilesRequest {
        const fileInfoList: FileInfo[] = Array.from(files).map(file => {
            const { path, size, type } = file;
            return { path, size, type };
        });

        return createRequest(fileInfoList);
    }

    function createRequestFromFileInfo(files: FileInfo[]): ProcessFilesRequest {
        return createRequest(files);
    }

    return { createRequestFromFileList, createRequestFromFileInfo }
}

export default validateFiles