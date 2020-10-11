import React from 'react';
import { ProcessResult } from '../lib/interfaces';

export interface CompleteProps {
    result: ProcessResult
}

const Complete = (props: CompleteProps) => {
    const { processed, total } = props.result;

    return (
        <>
            <h1>Complete!</h1>
            <p>✔️ Created { processed } of { total } videos.</p>
        </>
    )
}

export default Complete