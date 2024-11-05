export interface IEngineGlue {
	// Titlebar Events
	handleClickCloseWindow(): void;
	handleClickMaximizeWindow(): void;
	handleClickMinimizeWindow(): void;
	handleHoverCloseWindow(hover: boolean): void;
	handleHoverMaximizeWindow(hover: boolean): void;
	handleHoverMinimizeWindow(hover: boolean): void;
	handleHoverNonClientArea(hover: boolean): void;

	onClickCreateEmptyEntity(): void;
}

function logNotImplemented(functionName: string)
{
	console.log(`${functionName} not implemented.`)
}

class DevEngineGlue implements IEngineGlue {
	handleClickCloseWindow(): void
	{
		logNotImplemented("handleClickCloseWindow");
	}
	handleClickMaximizeWindow(): void
	{
		logNotImplemented("handleClickMaximizeWindow");
	}
	handleClickMinimizeWindow(): void
	{
		logNotImplemented("handleClickMinimizeWindow");
	}
	handleHoverCloseWindow(hover: boolean): void
	{
		logNotImplemented("handleHoverCloseWindow");
		console.log(`Hover ${hover}`)
	}
	handleHoverMaximizeWindow(hover: boolean): void
	{
		logNotImplemented("handleHoverMaximizeWindow");
		console.log(`Hover ${hover}`)
	}
	handleHoverMinimizeWindow(hover: boolean): void
	{
		logNotImplemented("handleHoverMinimizeWindow");
		console.log(`Hover ${hover}`)
	}
	handleHoverNonClientArea(hover: boolean): void
	{
		logNotImplemented("handleHoverNonClientArea");
		console.log(`Hover ${hover}`)
	}

	onClickCreateEmptyEntity(): void
	{
		logNotImplemented("onClickCreateEmptyEntity");
	}
}

// Globales Objekt deklarieren
declare global {
	interface Window {
		EngineGlue: IEngineGlue;
	}
}

// Initialisierung: DevEngineGlue als Fallback setzen wenn noch kein EngineGlue existiert
if (typeof window.EngineGlue === 'undefined') {
	window.EngineGlue = new DevEngineGlue();
}

// Export für einfacheren Zugriff in der Anwendung
export const EngineGlue: IEngineGlue = window.EngineGlue;
