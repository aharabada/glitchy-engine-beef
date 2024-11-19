import "./MainWindow.css"
import Dock from "../Components/Dock.tsx";
import {MenuBar, MenuDivider, MenuItem} from "../Components/Menu.tsx";
import {ReactElement, useEffect, useRef} from "react";
import '../EngineGlue.ts'
import {EngineGlue} from "../EngineGlue.ts";
import {StartupCard} from "../Components/StartupCard.tsx";

//something = 'testing';

export default function MainWindow() {
	const projectName = "Mein Geiles Projekt";
	const fileName = "DefaultScene.scene";

	return (
		<div className="jep">
			<TitleBar projectName={projectName} fileName={fileName}/>
			<Dock/>
		</div>
	);
}

function TitleBar({ projectName, fileName } : {projectName: string, fileName: string}): ReactElement
{
	// {false ? "🗗" : "🗖"}
	return (
		<div className="title-bar">
			<div className="title-bar__icon"/>
			<div className="title-bar__title"
			     onMouseEnter={() => EngineGlue.handleHoverNonClientArea(true)}
			     onMouseLeave={() => EngineGlue.handleHoverNonClientArea(false)}>
				<div>
					<span className="engine-name">Glitchy Engine</span> {projectName} - {fileName}
				</div>

				<button className="title-bar__button minimize"
				        onClick={() => EngineGlue.handleClickMinimizeWindow()}
				        onMouseOver={() => EngineGlue.handleHoverMinimizeWindow(true)}
				        onMouseLeave={() => EngineGlue.handleHoverMinimizeWindow(false)}>🗕</button>
				<button className="title-bar__button maximize"
				        onClick={() => EngineGlue.handleClickMaximizeWindow()}
						onMouseOver={() => EngineGlue.handleHoverMaximizeWindow(true)}
						onMouseLeave={() => EngineGlue.handleHoverMaximizeWindow(false)}>🗖</button>
				<button className="title-bar__button close"
				        onClick={() => EngineGlue.handleClickCloseWindow()}
				        onMouseOver={() => EngineGlue.handleHoverCloseWindow(true)}
				        onMouseLeave={() => EngineGlue.handleHoverCloseWindow(false)}>🗙</button>
			</div>
			<MainMenuBar/>
		</div>
	);
}

function MainMenuBar(): ReactElement
{
	return (
		<MenuBar>
			<MenuItem text="File" onClick={() => {
				console.log("Test")
			}}>
				<MenuItem text="New Scene..." hotkey="Ctrl + N" onClick={() => window.open("file:///index.html")}/>
				<MenuItem text="Open Scene..." hotkey="Ctrl + O"/>
				<MenuItem text="Open recent Scene">
					<MenuItem text="1. Bli"/>
					<MenuItem text="2. Bla"/>
					<MenuItem text="3. Blub"/>
				</MenuItem>
				<MenuDivider/>
				<MenuItem text="Save Scene" hotkey="Ctrl + S"/>
				<MenuItem text="Save Scene as..." hotkey="Ctrl + Shift + S"/>
				<MenuDivider/>
				<MenuItem text="Create new Project..."/>
				<MenuItem text="Open Project..."/>
				<MenuItem text="Open recent Project">
					<MenuItem text="1. Bli"/>
					<MenuItem text="2. Bla"/>
					<MenuItem text="3. Blub"/>
				</MenuItem>
				<MenuDivider/>
				<MenuItem text="Settings..."/>
				<MenuDivider/>
				<MenuItem text="Exit" onClick={EngineGlue.handleClickCloseWindow} />
			</MenuItem>
			<MenuItem text="View">
				<MenuItem text="Asset Browser"/>
				<MenuItem text="Scene"/>
				<MenuItem text="Entity Hierarchy"/>
				<MenuItem text="Game"/>
				<MenuItem text="Inspector"/>
				<MenuItem text="Asset Viewer"/>
				<MenuItem text="Log"/>
			</MenuItem>
			<MenuItem text="Tools">
				<MenuItem text="Reload Script"/>
				<label>
					<input type="checkbox"/>
					Show ImGui Demo
				</label>
			</MenuItem>
		</MenuBar>
	);
}
