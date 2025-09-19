# services/radarr.ps1
BeforeAll {
    $Global:Services = @()

    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\services\radarr.ps1' | Resolve-Path
    . $includePath
}
AfterAll {
    $Global:Services = $Null
}
Describe "Radarr Service" {
    It "should add environment variables to the passed object" {
        $env:Radarr_SourcePath = 'C:/source.mkv'
        $env:Radarr_DestinationPath = 'C:/dest.mkv'
        $env:Radarr_InstanceName = 'TestInstance'
        $env:Radarr_ApplicationUrl = 'http://localhost:7878/'
        $env:Radarr_TransferMode = 'copy'
        $env:Radarr_Movie_Id = '1234'
        $env:Radarr_Movie_Title = 'Test Movie'
        $env:Radarr_Movie_Year = '2025'
        $env:Radarr_Movie_TmdbId = '5678'
        $env:Radarr_Movie_ImdbId = 'tt1234567'
        $env:Radarr_Movie_OriginalLanguage = 'en'
        $env:Radarr_Movie_Genres = 'Action,Adventure'
        $env:Radarr_Movie_Tags = 'tag1,tag2'
        $env:Radarr_Movie_In_Cinemas_Date = '2025-01-01'
        $env:Radarr_Movie_Physical_Release_Date = '2025-02-01'
        $env:Radarr_Movie_Overview = 'A test movie.'
        $env:Radarr_MovieFile_Id = '9999'
        $env:Radarr_MovieFile_RelativePath = 'Movies/Test Movie (2025)/source.mkv'
        $env:Radarr_MovieFile_Quality = 'HD-1080p'
        $env:Radarr_MovieFile_QualityVersion = '1'
        $env:Radarr_MovieFile_ReleaseGroup = 'TestGroup'
        $env:Radarr_MovieFile_SceneName = 'TestScene'
        $env:Radarr_Download_Client = 'qBittorrent'
        $env:Radarr_Download_Client_Type = 'torrent'
        $env:Radarr_Download_Id = 'DLID1234'
        $env:Radarr_MovieFile_MediaInfo_AudioChannels = '6'
        $env:Radarr_MovieFile_MediaInfo_AudioCodec = 'DTS'
        $env:Radarr_MovieFile_MediaInfo_AudioLanguages = 'en,fr'
        $env:Radarr_MovieFile_MediaInfo_Languages = 'en,fr'
        $env:Radarr_MovieFile_MediaInfo_Height = '1080'
        $env:Radarr_MovieFile_MediaInfo_Width = '1920'
        $env:Radarr_MovieFile_MediaInfo_Subtitles = 'en,es'
        $env:Radarr_MovieFile_MediaInfo_VideoCodec = 'H264'
        $env:Radarr_MovieFile_MediaInfo_VideoDynamicRangeType = 'SDR'
        $env:Radarr_MovieFile_CustomFormat = 'Custom1'
        $env:Radarr_MovieFile_CustomFormatScore = '10'
        $env:Radarr_Movie_Path = 'C:/Movies/Test Movie (2025)'
        $env:Radarr_MovieFile_Path = 'C:/Movies/Test Movie (2025)/source.mkv'
        $env:Radarr_DeletedRelativePaths = 'old1.mkv,old2.mkv'
        $env:Radarr_DeletedPaths = 'C:/old1.mkv,C:/old2.mkv'
        $env:Radarr_DeletedDateAdded = '2025-03-01'

        $inputData = @{}
        $serviceFunc = $Services[-1]
        $result = & $serviceFunc $inputData

        # Check top-level assignments
        $result.sourceFile | Should -Be 'C:/source.mkv'
        $result.destinationFile | Should -Be 'C:/dest.mkv'

        $meta = $result.meta
        $meta["instanceName"] | Should -Be 'TestInstance'
        $meta["applicationUrl"] | Should -Be 'http://localhost:7878/'
        $meta["transferMode"] | Should -Be 'copy'
        $meta["movieId"] | Should -Be '1234'
        $meta["name"] | Should -Be 'Test Movie'
        $meta["year"] | Should -Be '2025'
        $meta["tmdbid"] | Should -Be '5678'
        $meta["imdbid"] | Should -Be 'tt1234567'
        $meta["originalLanguage"] | Should -Be 'en'
        $meta["genres"] | Should -Be 'Action,Adventure'
        $meta["tags"] | Should -Be 'tag1,tag2'
        $meta["inCinemas"] | Should -Be '2025-01-01'
        $meta["physicalRelease"] | Should -Be '2025-02-01'
        $meta["overview"] | Should -Be 'A test movie.'
        $meta["movieFileId"] | Should -Be '9999'
        $meta["relativePath"] | Should -Be 'Movies/Test Movie (2025)/source.mkv'
        $meta["quality"] | Should -Be 'HD-1080p'
        $meta["qualityVersion"] | Should -Be '1'
        $meta["releaseGroup"] | Should -Be 'TestGroup'
        $meta["sceneName"] | Should -Be 'TestScene'
        $meta["downloadClient"] | Should -Be 'qBittorrent'
        $meta["downloadClientType"] | Should -Be 'torrent'
        $meta["downloadId"] | Should -Be 'DLID1234'
        $meta["audioChannels"] | Should -Be '6'
        $meta["audioCodec"] | Should -Be 'DTS'
        $meta["audioLanguages"] | Should -Be 'en,fr'
        $meta["languages"] | Should -Be 'en,fr'
        $meta["videoHeight"] | Should -Be '1080'
        $meta["videoWidth"] | Should -Be '1920'
        $meta["subtitles"] | Should -Be 'en,es'
        $meta["videoCodec"] | Should -Be 'H264'
        $meta["videoDynamicRange"] | Should -Be 'SDR'
        $meta["customFormats"] | Should -Be 'Custom1'
        $meta["customFormatScore"] | Should -Be '10'
        $meta["moviePath"] | Should -Be 'C:/Movies/Test Movie (2025)'
        $meta["fullMovieFilePath"] | Should -Be 'C:/Movies/Test Movie (2025)/source.mkv'
        $meta["deletedRelativePaths"] | Should -Be 'old1.mkv,old2.mkv'
        $meta["deletedPaths"] | Should -Be 'C:/old1.mkv,C:/old2.mkv'
        $meta["deletedDateAdded"] | Should -Be '2025-03-01'
    }
}