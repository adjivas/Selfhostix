import WorkspacesExplorer from "@/features/explorer/components/workspaces-explorer/WorkspacesExplorer";
import { getGlobalExplorerLayout } from "@/features/layouts/components/explorer/ExplorerLayout";
import { useDefaultRoute } from "@/hooks/useDefaultRoute";
import { DefaultRoute } from "@/utils/defaultRoutes";

export default function FavoritesPage() {
  useDefaultRoute(DefaultRoute.FAVORITES);
  return <WorkspacesExplorer defaultFilters={{ is_favorite: true }} />;
}

FavoritesPage.getLayout = getGlobalExplorerLayout;
