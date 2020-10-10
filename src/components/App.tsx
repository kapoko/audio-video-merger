import React, { useState } from 'react';
// import { hot } from 'react-hot-loader';
import DropZone from './DropZone';
import validateFiles from '../lib/validateFiles';
import { processFilesRequest } from '../lib/interfaces';

enum ScreenState {
    SelectFiles,
    Processing
}

function App() {
    const { checkFiles } = validateFiles();
    const [screenState, setScreenState] = useState(ScreenState.SelectFiles);

    function handleDrop(files: FileList) {
        const request: processFilesRequest = checkFiles(files);

        if (!request.isValid) { 
            window.api.send('showDialog', {
                message: 'Select at least one audio and one video file.'
            });
        }
    }

    function renderScreen(screen: ScreenState) {
        switch (screen) {
            case ScreenState.SelectFiles:
                return <DropZone onDropFiles={handleDrop} />
        }

        return null;
    }

    return renderScreen(screenState);
}

export default App;