import * as path from 'path';
import * as fs from 'fs';
import * as ffmpeg from 'fluent-ffmpeg';
import { app, BrowserWindow, ipcMain, dialog } from 'electron';
import { ProcessFilesRequest, SingleProcessOptions, ProcessResult } from './lib/interfaces';
import { getSeconds } from './lib/helpers'
import { IpcMainEvent } from 'electron/main';

declare const MAIN_WINDOW_WEBPACK_ENTRY: any;
declare const MAIN_WINDOW_PRELOAD_WEBPACK_ENTRY: any;

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require('electron-squirrel-startup')) { // eslint-disable-line global-require
  app.quit();
}

let mainWindow: BrowserWindow;
const gotTheLock = app.requestSingleInstanceLock()

const createWindow = (): void => {
  // Create the browser window.
  mainWindow = new BrowserWindow({
    width: 640,
    height: 480,
    resizable: false,
    show: false,
    webPreferences: {
      nodeIntegration: false,
      worldSafeExecuteJavaScript: true,
      contextIsolation: true,
      preload: MAIN_WINDOW_PRELOAD_WEBPACK_ENTRY,
      devTools: !app.isPackaged
    }
  });

  mainWindow.loadURL(MAIN_WINDOW_WEBPACK_ENTRY);

  if (!app.isPackaged) {
    mainWindow.webContents.openDevTools();
  }

  mainWindow.once('ready-to-show', () => {
    mainWindow.show()
  })
};

if (!gotTheLock) {
  app.quit()
} else {
  app.on('second-instance', (event, commandLine, workingDirectory) => {
    // Someone tried to run a second instance, we should focus our window.
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore()
      mainWindow.focus()
    }
  })

  // Create myWindow, load the rest of the app, etc...
  app.on('ready', createWindow);
}

if (process.argv.length >= 2) {
  const filePath = process.argv[1]
  console.log(filePath);
}

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

//Get the paths to the packaged versions of the binaries we want to use
const ffmpegPath = require('ffmpeg-static').replace(
  'app.asar',
  'app.asar.unpacked'
);
const ffprobePath = require('ffprobe-static').path.replace(
    'app.asar',
    'app.asar.unpacked'
);

ffmpeg.setFfmpegPath(ffmpegPath);
ffmpeg.setFfprobePath(ffprobePath);

function processVideo(options: SingleProcessOptions, totalBytesProcessed: number, totalBytes: number, event: IpcMainEvent) {
  return new Promise((resolve, reject) => {
    let duration: number | false;

    ffmpeg.default()
      .input(options.video.path)
      .addInput(options.audio.path)
      .outputOptions([
        '-c:v copy',
        '-map 0:v:0',
        '-map 1:a:0'
      ])
      .on('codecData', data => duration = data.video_details ? getSeconds(data.duration) : false)
      .on('end', resolve)
      .on('error', error => reject(error.message))
      .on('progress', (progress) => {
        const timemark = getSeconds(progress.timemark)
        if (duration && timemark) { // Only send progress if we have enough info
          const currentProgress = Math.min(timemark / duration, 1);
          const currentBytesProcessed = currentProgress * options.bytes;
          event.reply('merge:progress', (totalBytesProcessed + currentBytesProcessed) / totalBytes)
        }
      })
      .save(options.output);
  }); 
}

ipcMain.on('merge', async (event, input: ProcessFilesRequest) => {
  const { videoList, audioList } = input;

  let processChain: SingleProcessOptions[] = [];
  let yesToAll: boolean = false;
  let noToAll: boolean = false;

  // Loop over all videos and audio
  videoList.forEach(video => {
    audioList.forEach(audio => {
      const dir = path.dirname(video.path);
      const fileName = path.basename(audio.path, path.extname(audio.path)) + path.extname(video.path);
      const videoBaseName = path.basename(video.path, path.extname(video.path));

      const output = videoList.length > 1 ? path.join(dir, videoBaseName + '_' + fileName) : path.join(dir, fileName);
      
      if (fs.existsSync(output) && !yesToAll && !noToAll) {  
        const result: number = dialog.showMessageBoxSync(mainWindow, {
          type: 'question',
          message: 'The file ' + path.basename(output) + ' already exists in the source folder. Overwrite it?',
          buttons: ['Yes to all', 'Yes', 'Cancel']
        })

        switch (result) {
          case 0: // Yes to all
            yesToAll = true;
            break;
          case 1: // Yes (do nothing)
            break;
          case 2: // Cancel 
            event.reply('merge:cancel')
            noToAll = true;
            break;
        }
      }

      processChain.push({ video, audio, output, bytes: audio.size + video.size});
    });
  });

  if (noToAll) {
    return;
  }

  const result: ProcessResult = { 
    processed: 0, 
    total: input.numVideos,
    errors: []
  }

  // Gather total bytesize to process for making an estimation on the progress
  const totalBytes: number = processChain.reduce((total, process) => total += process.bytes, 0)
  let bytesProcessed: number = 0;

  for (const current of processChain) {
    await processVideo(current, bytesProcessed, totalBytes, event).then(() => {
      bytesProcessed += current.bytes;
      console.log({bytesProcessed, totalBytes});
      result.processed++;
      event.reply('merge:progress', bytesProcessed / totalBytes)
    }).catch(result.errors.push)
  }
  
  event.reply(result.errors.length ? 'merge:error' : 'merge:complete', result);
});

ipcMain.on('showDialog', (event, options) => {
  dialog.showMessageBox(mainWindow, options);
});