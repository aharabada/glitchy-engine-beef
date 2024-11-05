import {createContext, PropsWithChildren, useContext, useRef, useState} from "react";

import "./Menu.css"
import {useClickOutside} from "../Callbacks/UseClickOutside.tsx";

export const OpenMenuContext = createContext<{openMenu: string[], currentParentMenu: string[], onOpenMenu: (clickedMenu: string[]) => void}>({openMenu: [], currentParentMenu: [], onOpenMenu: () => {}});

export function MenuBar({children}: PropsWithChildren)
{
	const ref = useRef(null);

	const [openMenu, setOpenMenu] = useState<string[]>([]);

	function handleClickOutside()
	{
		setOpenMenu([]);
	}

	useClickOutside(ref, handleClickOutside, openMenu.length > 0);

	function handleOpenSubmenu(clickedMenu: string[])
	{
		setOpenMenu(clickedMenu);
	}

	return (
		<ul ref={ref} className="menu-bar">
			<OpenMenuContext.Provider value={{openMenu, currentParentMenu: [], onOpenMenu: handleOpenSubmenu}}>
				{children}
			</OpenMenuContext.Provider>
		</ul>
	);
}

export function MenuItem({ text, hotkey, onClick, children } : { text: string, hotkey?: string, onClick?: () => void} & PropsWithChildren)
{
	const {openMenu, currentParentMenu, onOpenMenu: setOpenMenu} = useContext(OpenMenuContext);

	const isOpen = openMenu[currentParentMenu.length] == text;

	const hasSubmenu = children !== undefined;

	const currentMenu = [...currentParentMenu, text];

	function handleClick()
	{
		if (hasSubmenu)
		{
			setOpenMenu(isOpen ? currentParentMenu : currentMenu);
		}

		if (onClick)
		{
			onClick();
		}
	}

	return (
		<li className="menu-item">
			<a href="#" onClick={handleClick}>
				<div className="menu-item__content">
					<div>{text}</div>
					{hotkey && <div className="menu-item__hotkey">{hotkey}</div>}
				</div>
			</a>
			{children && (
				<ul className={`sub-menu ${isOpen ? "open" : ""}`}>
					<OpenMenuContext.Provider
						value={{openMenu, currentParentMenu: currentMenu, onOpenMenu: setOpenMenu}}>
						{children}
					</OpenMenuContext.Provider>
				</ul>
			)}
		</li>
	);
}

export function MenuDivider()
{
	return <hr/>;
}
