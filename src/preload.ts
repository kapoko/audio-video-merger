import { ipcRenderer, contextBridge } from 'electron'

declare global {
    interface Window {
        api: {
            send: (channel: string, data: any) => void,
            receive: (channel: string, func: (args? :any) => void) => void
        }
    }
}

contextBridge.exposeInMainWorld(
    'api', {
        send: (channel: string, data: any) => {
            let validChannels = ['showDialog', 'merge'];
            if (validChannels.includes(channel)) {
                ipcRenderer.send(channel, data);
            }
        },
        receive: (channel: string, func: (args?: any) => void) => {
            let validChannels = ['merge:progress', 'merge:complete', 'merge:cancel'];
            if (validChannels.includes(channel)) {
                // Deliberately strip event as it includes `sender` 
                ipcRenderer.on(channel, (event: any, ...args: any) => func(...args));
            }
        }
    }
);