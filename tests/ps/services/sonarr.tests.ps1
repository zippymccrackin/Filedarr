# services/sonarr.ps1
BeforeAll {
    $Global:Services = @()

    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\services\sonarr.ps1' | Resolve-Path
    . $includePath
}
AfterAll {
    $Global:Services = $Null
}
Describe "Sonarr Service" {
    It "should add environment variables to the passed object" {
        # Set all environment variables used in sonarr.ps1
        $env:Sonarr_SourcePath = 'C:/source.mkv'
        $env:Sonarr_DestinationPath = 'C:/dest.mkv'
        $env:Sonarr_InstanceName = 'TestInstance'
        $env:Sonarr_ApplicationUrl = 'http://localhost:8989/'
        $env:Sonarr_TransferMode = 'move'
        $env:Sonarr_Series_Id = '4321'
        $env:Sonarr_Series_Title = 'Test Series'
        $env:Sonarr_Series_TitleSlug = 'test-series'
        $env:Sonarr_Series_Path = 'C:/TV/Test Series'
        $env:Sonarr_Series_TvdbId = 'tvdb1234'
        $env:Sonarr_Series_TvMazeId = 'maze5678'
        $env:Sonarr_Series_TmdbId = 'tmdb9999'
        $env:Sonarr_Series_ImdbId = 'tt7654321'
        $env:Sonarr_Series_Type = 'standard'
        $env:Sonarr_Series_OriginalLanguage = 'en'
        $env:Sonarr_Series_Genres = 'Drama,Comedy'
        $env:Sonarr_Series_Tags = 'tagA,tagB'
        $env:Sonarr_EpisodeFile_EpisodeCount = '2'
        $env:Sonarr_EpisodeFile_EpisodeIds = '101,102'
        $env:Sonarr_EpisodeFile_SeasonNumber = '1'
        $env:Sonarr_EpisodeFile_EpisodeNumbers = '1,2'
        $env:Sonarr_EpisodeFile_EpisodeAirDates = '2025-01-01,2025-01-08'
        $env:Sonarr_EpisodeFile_EpisodeAirDatesUtc = '2025-01-01T00:00:00Z,2025-01-08T00:00:00Z'
        $env:Sonarr_EpisodeFile_EpisodeTitles = 'Pilot,Second'
        $env:Sonarr_EpisodeFile_EpisodeOverviews = 'First ep,Second ep'
        $env:Sonarr_EpisodeFile_Quality = 'HD-720p'
        $env:Sonarr_EpisodeFile_QualityVersion = '2'
        $env:Sonarr_EpisodeFile_ReleaseGroup = 'TestGroup'
        $env:Sonarr_EpisodeFile_SceneName = 'TestScene'
        $env:Sonarr_Download_Client = 'qBittorrent'
        $env:Sonarr_Download_Client_Type = 'torrent'
        $env:Sonarr_Download_Id = 'DLID5678'
        $env:Sonarr_EpisodeFile_MediaInfo_AudioChannels = '2'
        $env:Sonarr_EpisodeFile_MediaInfo_AudioCodec = 'AAC'
        $env:Sonarr_EpisodeFile_MediaInfo_AudioLanguages = 'en,es'
        $env:Sonarr_EpisodeFile_MediaInfo_Languages = 'en,es'
        $env:Sonarr_EpisodeFile_MediaInfo_Height = '720'
        $env:Sonarr_EpisodeFile_MediaInfo_Width = '1280'
        $env:Sonarr_EpisodeFile_MediaInfo_Subtitles = 'en,fr'
        $env:Sonarr_EpisodeFile_MediaInfo_VideoCodec = 'H265'
        $env:Sonarr_EpisodeFile_MediaInfo_VideoDynamicRangeType = 'HDR'
        $env:Sonarr_EpisodeFile_CustomFormat = 'Custom2'
        $env:Sonarr_EpisodeFile_CustomFormatScore = '20'
        $env:Sonarr_DeletedRelativePaths = 'oldEp1.mkv,oldEp2.mkv'
        $env:Sonarr_DeletedPaths = 'C:/oldEp1.mkv,C:/oldEp2.mkv'
        $env:Sonarr_DeletedDateAdded = '2025-04-01'
        $env:Sonarr_DeletedRecycleBinPaths = 'C:/recycle1.mkv,C:/recycle2.mkv'

        $inputData = @{}
        $serviceFunc = $Services[-1]
        $result = & $serviceFunc $inputData

        # Check top-level assignments
        $result.sourceFile | Should -Be 'C:/source.mkv'
        $result.destinationFile | Should -Be 'C:/dest.mkv'

        $meta = $result.meta
        $meta["instanceName"] | Should -Be 'TestInstance'
        $meta["applicationUrl"] | Should -Be 'http://localhost:8989/'
        $meta["transferMode"] | Should -Be 'move'
        $meta["seriesId"] | Should -Be '4321'
        $meta["name"] | Should -Be 'Test Series'
        $meta["titleSlug"] | Should -Be 'test-series'
        $meta["seriesPath"] | Should -Be 'C:/TV/Test Series'
        $meta["tvdbid"] | Should -Be 'tvdb1234'
        $meta["tvMazeId"] | Should -Be 'maze5678'
        $meta["tmdbId"] | Should -Be 'tmdb9999'
        $meta["imdbId"] | Should -Be 'tt7654321'
        $meta["seriesType"] | Should -Be 'standard'
        $meta["originalLanguage"] | Should -Be 'en'
        $meta["genres"] | Should -Be 'Drama,Comedy'
        $meta["tags"] | Should -Be 'tagA,tagB'
        $meta["episodeCount"] | Should -Be '2'
        $meta["episodeIds"] | Should -Be '101,102'
        $meta["seasonNumber"] | Should -Be '1'
        $meta["episodeNumber"] | Should -Be '1,2'
        $meta["airDates"] | Should -Be '2025-01-01,2025-01-08'
        $meta["airDatesUtc"] | Should -Be '2025-01-01T00:00:00Z,2025-01-08T00:00:00Z'
        $meta["episodeTitles"] | Should -Be 'Pilot,Second'
        $meta["episodeOverviews"] | Should -Be 'First ep,Second ep'
        $meta["quality"] | Should -Be 'HD-720p'
        $meta["qualityVersion"] | Should -Be '2'
        $meta["releaseGroup"] | Should -Be 'TestGroup'
        $meta["sceneName"] | Should -Be 'TestScene'
        $meta["downloadClient"] | Should -Be 'qBittorrent'
        $meta["downloadClientType"] | Should -Be 'torrent'
        $meta["downloadId"] | Should -Be 'DLID5678'
        $meta["audioChannels"] | Should -Be '2'
        $meta["audioCodec"] | Should -Be 'AAC'
        $meta["audioLanguages"] | Should -Be 'en,es'
        $meta["languages"] | Should -Be 'en,es'
        $meta["height"] | Should -Be '720'
        $meta["width"] | Should -Be '1280'
        $meta["subtitles"] | Should -Be 'en,fr'
        $meta["videoCodec"] | Should -Be 'H265'
        $meta["videoDynamicRangeType"] | Should -Be 'HDR'
        $meta["customFormat"] | Should -Be 'Custom2'
        $meta["customFormatScore"] | Should -Be '20'
        $meta["deletedRelativePaths"] | Should -Be 'oldEp1.mkv,oldEp2.mkv'
        $meta["deletedPaths"] | Should -Be 'C:/oldEp1.mkv,C:/oldEp2.mkv'
        $meta["deletedDateAdded"] | Should -Be '2025-04-01'
        $meta["deletedRecycleBinPaths"] | Should -Be 'C:/recycle1.mkv,C:/recycle2.mkv'
    }
}