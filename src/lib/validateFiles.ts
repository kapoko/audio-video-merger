import { processFilesRequest } from './interfaces';

const validateFiles = () => {
    function checkFiles(files: FileList): processFilesRequest {
        const result: processFilesRequest = { audio: [], video: [] }

        for(let i = 0; i < files.length; i++) {
            const { type } = files[i];

            switch(type) {
                case 'audio/mpeg':
                case 'audio/mp4': 
                case 'audio/x-aiff': 
                case 'audio/vnd.wav': 
                case 'audio/vorbis': 
                case 'audio/wav': 
                    result.audio.push(files[i].path)
                    break;
                case 'video/mp4':   
                case 'video/quicktime':    
                case 'video/H264':
                case 'video/H265':
                    result.video.push(files[i].path)
                    break;
            }
        }

        return {
            isValid: !!result.audio.length && !!result.video.length,
            ...result
        }
    }

    return { checkFiles }
}

export default validateFiles