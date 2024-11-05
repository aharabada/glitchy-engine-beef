import {RefObject, useEffect} from "react";

/**
 * Calls the specified callback when the user clicks somewhere outside the referenced HTML-Element.
 * @param ref The element.
 * @param callback The callback.
 * @param addEventListener If true, the event listener will be registered.
 */
export const useClickOutside = (
	ref: RefObject<HTMLElement | undefined>,
	callback: () => void,
	addEventListener = true,
) => {
	useEffect(() => {
		const handleClick = (event: MouseEvent) => {
			if (ref.current && !ref.current.contains(event.target as HTMLElement))
			{
				callback();
			}
		}

		if (addEventListener)
		{
			document.addEventListener('click', handleClick);
		}

		return () => {
			document.removeEventListener('click', handleClick);
		}
	})
}
