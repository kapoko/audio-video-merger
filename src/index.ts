import { app, BrowserWindow, ipcMain, dialog } from 'electron';
declare const MAIN_WINDOW_WEBPACK_ENTRY: any;

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require('electron-squirrel-startup')) { // eslint-disable-line global-require
  app.quit();
}

let mainWindow: BrowserWindow;

const createWindow = (): void => {
  // Create the browser window.
  mainWindow = new BrowserWindow({
    height: 480,
    width: 640,
    resizable: false,
    webPreferences: {
      nodeIntegration: true,
      devTools: false
    }
  });

  // and load the index.html of the app.
  mainWindow.loadURL(MAIN_WINDOW_WEBPACK_ENTRY);

  // Open the DevTools.
  mainWindow.webContents.openDevTools();
};

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', createWindow);

// Quit when all windows are closed, except on macOS. There, it's common
// for applications and their menu bar to stay active until the user quits
// explicitly with Cmd + Q.
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and import them here.
import * as ffmpeg from 'fluent-ffmpeg';
import { ffmpegInput, singleProcessOptions } from './interfaces';
import * as fs from 'fs';
import * as path from 'path';

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

function processVideo(options: singleProcessOptions) {
  return new Promise((resolve, reject) => {
    ffmpeg.default()
      .input(options.videoPath)
      .addInput(options.audioPath)
      .outputOptions([
        '-c:v copy',
        '-map 0:v:0',
        '-map 1:a:0'
      ])
      .on('end', resolve)
      .on('error', reject)
      .save(options.output);
  }); 
}

ipcMain.on('merge', async (event, input: ffmpegInput) => {
  const { video, audio } = input;

  let processChain: singleProcessOptions[] = [];

  // Loop over all videos and audio
  video.forEach((videoPath, index) => {
    audio.forEach(audioPath => {
      const dir = path.dirname(videoPath);
      const fileName = path.basename(audioPath, path.extname(audioPath)) + path.extname(videoPath);
      const videoBaseName = path.basename(videoPath, path.extname(videoPath));

      const output = video.length > 1 ? path.join(dir, videoBaseName + '_' + fileName) : path.join(dir, fileName)

      processChain.push({ videoPath, audioPath, output });
    });
  });

  let processCount = 0;
  for (const options of processChain) {
    await processVideo(options).catch(console.error).then(() => {
      event.reply('merge:progress', `${++processCount} of ${processChain.length} videos complete`)
    });
  }

  event.reply('merge:complete', `✅ Processed ${processCount} of ${processChain.length} videos`)
});

ipcMain.on('showDialog', (event, options) => {
  dialog.showMessageBox(mainWindow, options);
});