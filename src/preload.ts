import { ipcRenderer, contextBridge, type IpcRendererEvent } from "electron";

declare global {
    interface Window {
        api: {
            send: <T>(channel: string, data: T) => void;
            on: <T>(channel: string, callback: (...args: T[]) => void) => void;
            once: <T>(channel: string, callback: (...args: T[]) => void) => void;
            removeAllListeners: (channels: string[]) => void;
        };
    }
}

const validSendChannels = ["showDialog", "showOpenDialog", "merge"];

const validReceiveChannels = [
    "merge:progress",
    "merge:complete",
    "merge:cancel",
    "merge:error",
    "merge:start",
    "merge:waiting",
    "showOpenDialog:response",
];

contextBridge.exposeInMainWorld("api", {
    send: <T>(channel: string, data: T) => {
        if (validSendChannels.includes(channel)) {
            ipcRenderer.send(channel, data);
        }
    },
    on: <T>(channel: string, callback: (...args: T[]) => void) => {
        if (validReceiveChannels.includes(channel)) {
            ipcRenderer.on(channel, (_: IpcRendererEvent, ...args: T[]) =>
                callback(...args),
            );
        }
    },
    once: <T>(channel: string, callback: (...args: T[]) => void) => {
        if (validReceiveChannels.includes(channel)) {
            ipcRenderer.once(channel, (_: IpcRendererEvent, ...args: T[]) =>
                callback(...args),
            );
        }
    },
    removeAllListeners: (channels: string[]) => {
        for (const channel of channels) {
            ipcRenderer.removeAllListeners(channel);
        }
    },
});
