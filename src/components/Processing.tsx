import React from 'react';

export interface ProcessingProps {
    progress: number
}

const radius = 90;
const strokeWidth = 10;
const circumference = radius * 2 * Math.PI;

const Processing: React.FunctionComponent<ProcessingProps> = (props: ProcessingProps) => {
    const circleStyles = { 
        strokeDashoffset: circumference - props.progress * circumference,
        strokeDasharray: `${circumference} ${circumference}`
    }

    const progressRingStyles = {
        width: radius * 2 + strokeWidth,
        height: radius * 2 + strokeWidth
    }

    return (
        <>
            <div className="progress-ring" style={progressRingStyles}>
                <svg className="ring" height={ radius * 2 + strokeWidth } width={ radius * 2 + strokeWidth }>
                    <defs>
                        <linearGradient id="gradient" x1="0%" y1="0%" x2="0%" y2="100%">
                            <stop offset="0%" stopColor="#fbc50c" />
                            <stop offset="100%" stopColor="#be3d16" />
                        </linearGradient>
                    </defs>
                    <circle
                        className="circle-background"
                        strokeWidth={ strokeWidth }
                        fill="transparent"
                        r={ radius }
                        cx={ radius + strokeWidth / 2}
                        cy={ radius + strokeWidth / 2}
                    />
                    <circle
                        className="circle"
                        strokeWidth={ strokeWidth }
                        fill="transparent"
                        stroke="url(#gradient)"
                        r={ radius }
                        cx={ radius + strokeWidth / 2}
                        cy={ radius + strokeWidth / 2}
                        style={circleStyles}
                    />
                </svg>
                <h1 className="progress">{ Math.round(props.progress * 100) }<small>%</small></h1>
            </div>
        </>
    )
}

export default Processing