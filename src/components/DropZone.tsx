import React, { useState } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faFolderOpen } from '@fortawesome/free-solid-svg-icons'
import { FileInfo } from '../lib/interfaces';

export interface DropZoneProps {
    onDropFiles(files: FileList): void
    onOpenFiles(fileInfoList: FileInfo[]): void
}

const DropZone = (props: DropZoneProps) => {

    const [dragging, setDragging] = useState(false);
    const [enterTarget, setEnterTarget] = useState<EventTarget>();
    
    function handleDrop(event: React.DragEvent) {
        event.preventDefault();
        event.stopPropagation();

        if (!dragging) {
            return;
        }

        setDragging(false);

        const { files } = event.dataTransfer;
        props.onDropFiles(files);
    }

    function handleDragEnter(e: React.DragEvent) {
        setEnterTarget(e.target);
        setDragging(true);
    }

    function handleDragLeave(e: React.DragEvent) {
        if (e.target == enterTarget) {
            setDragging(false);
        }
    }

    function dragPreventDefault(event: React.DragEvent) {
        event.preventDefault();
    }

    function handleClick() {
        window.api.send('showOpenDialog', {
            message: 'Select audio and video files',
            properties: ['openFile', 'multiSelections']
        });

        window.api.once('showOpenDialog:response', (fileInfoList: FileInfo[]) => {
            if (fileInfoList.length) {
                props.onOpenFiles(fileInfoList);
            }
        });
    }

    return (
        <div id="drop-zone" className={`drop-zone ${dragging ? 'is-dragging' : ''}`}
            onDrop={handleDrop} 
            onDragOver={dragPreventDefault} 
            onDragEnter={handleDragEnter}
            onDragLeave={handleDragLeave}>
            { !dragging
                ? <h1>Drop audio and video files here</h1>
                : <h1>Cast it into the fire! 🔥</h1>
            }
            <button className="mdc-fab" aria-label="Open files" onClick={handleClick}>
                <div className="mdc-fab__ripple"></div>
                <span className="mdc-fab__icon">
                    <FontAwesomeIcon icon={faFolderOpen} />
                </span>
            </button>
        </div>
    );
}

export default DropZone