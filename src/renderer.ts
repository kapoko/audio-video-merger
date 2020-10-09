/**
 * This file will automatically be loaded by webpack and run in the "renderer" context.
 * To learn more about the differences between the "main" and the "renderer" context in
 * Electron, visit:
 *
 * https://electronjs.org/docs/tutorial/application-architecture#main-and-renderer-processes
 *
 * By default, Node.js integration in this file is disabled. When enabling Node.js integration
 * in a renderer process, please be aware of potential security implications. You can read
 * more about security risks here:
 *
 * https://electronjs.org/docs/tutorial/security
 *
 * To enable Node.js integration in this file, open up `main.js` and enable the `nodeIntegration`
 * flag:
 *
 * ```
 *  // Create the browser window.
 *  mainWindow = new BrowserWindow({
 *    width: 800,
 *    height: 600,
 *    webPreferences: {
 *      nodeIntegration: true
 *    }
 *  });
 * ```
 */

import { ipcRenderer } from 'electron';
import { ffmpegInput } from './interfaces';
import './index.scss';

const dropZone: HTMLElement = document.getElementById('drop-zone');
const progressEl: HTMLElement = document.getElementById('progress');

function processInput(fileList: FileList): ffmpegInput {
    const result: ffmpegInput = { audio: [], video: [] }

    for(let i = 0; i < fileList.length; i++) {
        const { type } = fileList[i];

        switch(type) {
            case 'audio/mpeg':
            case 'audio/mp4': 
            case 'audio/x-aiff': 
            case 'audio/vnd.wav': 
            case 'audio/vorbis': 
            case 'audio/wav': 
                result.audio.push(fileList[i].path)
                break;
            case 'video/mp4':   
            case 'video/quicktime':    
            case 'video/H264':
            case 'video/H265':
                result.video.push(fileList[i].path)
                break;
        }
    }

    return {
        isValid: !!result.audio.length && !!result.video.length,
        ...result
    }
}

dropZone.addEventListener('drop', (event) => { 
    event.preventDefault(); 
    event.stopPropagation(); 
    dropZone.classList.remove('is-active');

    const { files } = event.dataTransfer;
    const input: ffmpegInput = processInput(files);

    if (!input.isValid) {
        ipcRenderer.send('showDialog', {
            title: 'jaja',
            message: 'Select at least one audio and one video file.'
        });
        return;
    }

    console.log(input)
    ipcRenderer.send('merge', input);
});
  
dropZone.addEventListener('dragover', (e) => { 
    e.preventDefault(); 
    e.stopPropagation(); 
});
  
dropZone.addEventListener('dragenter', (event) => { 
    dropZone.classList.add('is-active');
}); 
  
dropZone.addEventListener('dragleave', (event) => { 
    dropZone.classList.remove('is-active');
});

ipcRenderer.on('merge:progress', (event, arg) => {
    progressEl.style.color = '';
    progressEl.textContent = arg;
});

ipcRenderer.on('merge:complete', (event, arg) => {
    progressEl.style.color = 'green';
    progressEl.textContent = arg;
    new Notification('Merging videos complete', { body: arg });
})