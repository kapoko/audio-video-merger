import { ProcessFilesRequest } from './interfaces';

const validateFiles = () => {
    function checkFiles(files: FileList): ProcessFilesRequest {
        const result: ProcessFilesRequest = { 
            audioList: [], 
            videoList: [], 
            numVideos: 0,
            isValid: false
        }

        for(let i = 0; i < files.length; i++) {
            const { type, path, size } = files[i];

            switch(type) {
                case 'audio/mpeg':
                case 'audio/mp4': 
                case 'audio/x-aiff': 
                case 'audio/vnd.wav': 
                case 'audio/vorbis': 
                case 'audio/wav': 
                    result.audioList.push({ path, size });
                    break;
                case 'video/mp4':   
                case 'video/quicktime':    
                case 'video/H264':
                case 'video/H265':
                    result.videoList.push({ path, size });
                    break;
            }
        }

        return {
            ...result,
            isValid: !!result.audioList.length && !!result.videoList.length,
            numVideos: result.audioList.length * result.videoList.length,
        }
    }

    return { checkFiles }
}

export default validateFiles