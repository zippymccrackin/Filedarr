$Services += {
    param($data)

    if( $env:Radarr_SourcePath ) {
        $data['sourceFile'] = $env:Radarr_SourcePath
        $data['destinationFile'] = $env:Radarr_DestinationPath

        $meta = @{}

        $meta["instanceName"]             = $env:Radarr_InstanceName
        $meta["applicationUrl"]           = $env:Radarr_ApplicationUrl
        $meta["transferMode"]             = $env:Radarr_TransferMode

        $meta["movieId"]                  = $env:Radarr_Movie_Id
        $meta["name"]                     = $env:Radarr_Movie_Title
        $meta["year"]                     = $env:Radarr_Movie_Year
        $meta["tmdbid"]                   = $env:Radarr_Movie_TmdbId
        $meta["imdbid"]                   = $env:Radarr_Movie_ImdbId
        $meta["originalLanguage"]         = $env:Radarr_Movie_OriginalLanguage
        $meta["genres"]                   = $env:Radarr_Movie_Genres
        $meta["tags"]                     = $env:Radarr_Movie_Tags
        $meta["inCinemas"]                = $env:Radarr_Movie_In_Cinemas_Date
        $meta["physicalRelease"]          = $env:Radarr_Movie_Physical_Release_Date
        $meta["overview"]                 = $env:Radarr_Movie_Overview

        $meta["movieFileId"]              = $env:Radarr_MovieFile_Id
        $meta["relativePath"]             = $env:Radarr_MovieFile_RelativePath
        $meta["quality"]                  = $env:Radarr_MovieFile_Quality
        $meta["qualityVersion"]           = $env:Radarr_MovieFile_QualityVersion
        $meta["releaseGroup"]             = $env:Radarr_MovieFile_ReleaseGroup
        $meta["sceneName"]                = $env:Radarr_MovieFile_SceneName

        $meta["downloadClient"]           = $env:Radarr_Download_Client
        $meta["downloadClientType"]       = $env:Radarr_Download_Client_Type
        $meta["downloadId"]               = $env:Radarr_Download_Id

        $meta["audioChannels"]            = $env:Radarr_MovieFile_MediaInfo_AudioChannels
        $meta["audioCodec"]               = $env:Radarr_MovieFile_MediaInfo_AudioCodec
        $meta["audioLanguages"]           = $env:Radarr_MovieFile_MediaInfo_AudioLanguages
        $meta["languages"]                = $env:Radarr_MovieFile_MediaInfo_Languages
        $meta["videoHeight"]              = $env:Radarr_MovieFile_MediaInfo_Height
        $meta["videoWidth"]               = $env:Radarr_MovieFile_MediaInfo_Width
        $meta["subtitles"]                = $env:Radarr_MovieFile_MediaInfo_Subtitles
        $meta["videoCodec"]               = $env:Radarr_MovieFile_MediaInfo_VideoCodec
        $meta["videoDynamicRange"]        = $env:Radarr_MovieFile_MediaInfo_VideoDynamicRangeType

        $meta["customFormats"]            = $env:Radarr_MovieFile_CustomFormat
        $meta["customFormatScore"]        = $env:Radarr_MovieFile_CustomFormatScore

        $meta["moviePath"]                = $env:Radarr_Movie_Path
        $meta["fullMovieFilePath"]        = $env:Radarr_MovieFile_Path

        # Optional: Deleted file paths if applicable
        $meta["deletedRelativePaths"]     = $env:Radarr_DeletedRelativePaths
        $meta["deletedPaths"]             = $env:Radarr_DeletedPaths
        $meta["deletedDateAdded"]         = $env:Radarr_DeletedDateAdded

        $data['meta'] = $meta
    }

    return $data
}