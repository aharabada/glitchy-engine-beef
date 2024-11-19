import {Entity, EntityId} from "./Entity.ts";

export interface IEngineGlue
{
	// Titlebar Events
	handleClickCloseWindow(): void;
	handleClickMaximizeWindow(): void;
	handleClickMinimizeWindow(): void;
	handleHoverCloseWindow(hover: boolean): void;
	handleHoverMaximizeWindow(hover: boolean): void;
	handleHoverMinimizeWindow(hover: boolean): void;
	handleHoverNonClientArea(hover: boolean): void;

	onClickCreateEmptyEntity(): void;
	setEntityVisibility(entityId: EntityId, isVisible: boolean): void;

	requestEntityHierarchyUpdate(): void;
	onUpdateEntities?: (entities: Entity[]) => void;
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
	setEntityVisibility(entityId: EntityId, isVisible: boolean): void
	{
		logNotImplemented("onClickCreateEmptyEntity");
		console.log(`entityId ${entityId} isVisible ${isVisible}`)
	}

	requestEntityHierarchyUpdate(): void
	{
		logNotImplemented("requestEntityHierarchyUpdate");
	}

	private callFromEngine_updateEntities(entities: Entity[]): void
	{
		console.log("Yeah!")

		if (EngineGlue.onUpdateEntities)
		{
			EngineGlue.onUpdateEntities(entities);
		}
		else
		{
			logNotImplemented("onUpdateEntities");
		}
	}
}

declare global
{
	interface Window
	{
		EngineGlue: IEngineGlue;
	}
}

if (typeof window.EngineGlue === 'undefined')
{
	window.EngineGlue = new DevEngineGlue();
}

export const EngineGlue: IEngineGlue = window.EngineGlue;
