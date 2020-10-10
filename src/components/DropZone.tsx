import React, { useState } from 'react';
// import withFileDrop, { WithFileDropProps } from './withFileDrop';

// interface DropZoneProps extends WithFileDropProps {}

export interface DropZoneProps {
    onDropFiles(files: FileList): void
}

const DropZone = (props: DropZoneProps) => {

    const [dragging, setDragging] = useState(false);

    function handleDrop(event: React.DragEvent) {
        event.preventDefault();
        event.stopPropagation();
        setDragging(false);

        const { files } = event.dataTransfer;
        props.onDropFiles(files);
    }

    function handleDragOver(event: React.DragEvent) {
        event.preventDefault();
    }

    return (
        <div id="drop-zone" className={`drop-zone ${dragging ? 'is-dragging' : ''}`}
            onDrop={handleDrop} 
            onDragOver={handleDragOver} 
            onDragEnter={() => setDragging(true)}
            onDragLeave={() => setDragging(false)}>
            { !dragging
                ? <h1>Drop audio and video files here</h1>
                : <h1>Cast it into the fire! 🔥</h1>
            }
        </div>
    );
}

export default DropZone