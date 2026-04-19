export default function domReady(callback: () => void): void {
	if (document.readyState === 'complete' || document.readyState === 'interactive') {
		void callback();
	}

	document.addEventListener('DOMContentLoaded', callback);
}