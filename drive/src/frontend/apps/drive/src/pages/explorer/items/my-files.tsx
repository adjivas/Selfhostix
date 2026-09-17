import WorkspacesExplorer from "@/features/explorer/components/workspaces-explorer/WorkspacesExplorer";
import { getGlobalExplorerLayout } from "@/features/layouts/components/explorer/ExplorerLayout";
import { DefaultRoute } from "@/utils/defaultRoutes";
import { useDefaultRoute } from "@/hooks/useDefaultRoute";

export default function MyFilesPage() {
  useDefaultRoute(DefaultRoute.MY_FILES);
  return <WorkspacesExplorer defaultFilters={{ is_creator_me: true }} />;
}

MyFilesPage.getLayout = getGlobalExplorerLayout;
