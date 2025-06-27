$Services += {
    param($data)

    # pull info if Sonarr
    if( $env:Sonarr_SourcePath ) {
        $data['sourceFile'] = $env:Sonarr_SourcePath
        $data['destinationFile'] = $env:Sonarr_DestinationPath

        $meta = @{}

        # all the info available from Sonarr env variables
        $meta["instanceName"] = $env:Sonarr_InstanceName
        $meta["name"] = $env:Sonarr_Series_Title
        $meta["titleSlug"] = $env:Sonarr_Series_TitleSlug
        $meta["seriesPath"] = $env:Sonarr_Series_Path
        $meta["tvdbid"] = $env:Sonarr_Series_TvdbId
        $meta["tvMazeId"] = $env:Sonarr_Series_TvMazeId
        $meta["tmdbId"] = $env:Sonarr_Series_TmdbId
        $meta["imdbId"] = $env:Sonarr_Series_ImdbId
        $meta["seriesType"] = $env:Sonarr_Series_Type
        $meta["originalLanguage"] = $env:Sonarr_Series_OriginalLanguage
        $meta["genres"] = $env:Sonarr_Series_Genres
        $meta["tags"] = $env:Sonarr_Series_Tags

        $meta["episodeCount"] = $env:Sonarr_EpisodeFile_EpisodeCount
        $meta["episodeIds"] = $env:Sonarr_EpisodeFile_EpisodeIds
        $meta["seasonNumber"] = $env:Sonarr_EpisodeFile_SeasonNumber
        $meta["episodeNumber"] = $env:Sonarr_EpisodeFile_EpisodeNumbers
        $meta["airDates"] = $env:Sonarr_EpisodeFile_EpisodeAirDates
        $meta["airDatesUtc"] = $env:Sonarr_EpisodeFile_EpisodeAirDatesUtc
        $meta["episodeTitles"] = $env:Sonarr_EpisodeFile_EpisodeTitles
        $meta["episodeOverviews"] = $env:Sonarr_EpisodeFile_EpisodeOverviews
        $meta["quality"] = $env:Sonarr_EpisodeFile_Quality
        $meta["qualityVersion"] = $env:Sonarr_EpisodeFile_QualityVersion
        $meta["releaseGroup"] = $env:Sonarr_EpisodeFile_ReleaseGroup
        $meta["sceneName"] = $env:Sonarr_EpisodeFile_SceneName

        $meta["downloadClient"] = $env:Sonarr_Download_Client
        $meta["downloadClientType"] = $env:Sonarr_Download_Client_Type
        $meta["downloadId"] = $env:Sonarr_Download_Id

        $meta["audioChannels"] = $env:Sonarr_EpisodeFile_MediaInfo_AudioChannels
        $meta["audioCodec"] = $env:Sonarr_EpisodeFile_MediaInfo_AudioCodec
        $meta["audioLanguages"] = $env:Sonarr_EpisodeFile_MediaInfo_AudioLanguages
        $meta["languages"] = $env:Sonarr_EpisodeFile_MediaInfo_Languages
        $meta["height"] = $env:Sonarr_EpisodeFile_MediaInfo_Height
        $meta["width"] = $env:Sonarr_EpisodeFile_MediaInfo_Width
        $meta["subtitles"] = $env:Sonarr_EpisodeFile_MediaInfo_Subtitles
        $meta["videoCodec"] = $env:Sonarr_EpisodeFile_MediaInfo_VideoCodec
        $meta["videoDynamicRangeType"] = $env:Sonarr_EpisodeFile_MediaInfo_VideoDynamicRangeType

        $meta["customFormat"] = $env:Sonarr_EpisodeFile_CustomFormat
        $meta["customFormatScore"] = $env:Sonarr_EpisodeFile_CustomFormatScore

        $meta["seriesId"] = $env:Sonarr_Series_Id
        $meta["applicationUrl"] = $env:Sonarr_ApplicationUrl
        $meta["transferMode"] = $env:Sonarr_TransferMode

        # Optional: deleted file metadata
        $meta["deletedRelativePaths"] = $env:Sonarr_DeletedRelativePaths
        $meta["deletedPaths"] = $env:Sonarr_DeletedPaths
        $meta["deletedDateAdded"] = $env:Sonarr_DeletedDateAdded
        $meta["deletedRecycleBinPaths"] = $env:Sonarr_DeletedRecycleBinPaths

        $data['meta'] = $meta
    }

    return $data
}