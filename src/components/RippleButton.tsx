import React, { useRef, useEffect } from 'react';
import { MDCRipple} from '@material/ripple';

interface IconProps {
    children?: React.ReactNode;
    className: string;
    onClick?: () => void;
}

export const RippleButton = (props: IconProps) => {

    const rippleRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (rippleRef.current) {
            new MDCRipple(rippleRef.current);
        }
    }, [])

    const {
        children,
        className = '',
        ...otherProps
    } = props;
        
    return (
        <div
            className={`ripple-icon-component ${className}`}
            ref={rippleRef}
            {...otherProps}>
            {children}
        </div>
    );
};