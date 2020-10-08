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

const { ipcRenderer } = require('electron')

import './index.scss';

const dropZone: HTMLElement = document.getElementById('drop-zone');

dropZone.addEventListener('drop', (event) => { 
    event.preventDefault(); 
    event.stopPropagation(); 
    dropZone.classList.remove('is-active');

    const { files } = event.dataTransfer;
    for(let i = 0; i < files.length; i++) {
        console.log('File Path of dragged files: ', files[i].path) 
        ipcRenderer.send('ffmpeg-test', files[i].path);
    }
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