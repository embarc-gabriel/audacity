#include "domconverter.h"

#include "au3types.h"
#include "libraries/lib-track/Track.h"
#include "libraries/lib-wave-track/WaveClip.h"
#include "libraries/lib-wave-track/WaveTrack.h"

#include "wxtypes_convert.h"

#include "../au3types.h"

using namespace au::au3;

namespace {
static au::trackedit::TrackType trackType(const Au3Track* track)
{
    switch (track->NChannels()) {
    case 0:
        return au::trackedit::TrackType::Label;
    case 1:
        return au::trackedit::TrackType::Mono;
    case 2:
        return au::trackedit::TrackType::Stereo;
    default:
        break;
    }

    return au::trackedit::TrackType::Undefined;
}
}

au::trackedit::Clip DomConverter::clip(const Au3WaveTrack* waveTrack, const Au3WaveClip* au3clip)
{
    au::trackedit::Clip clip;
    clip.key.trackId = waveTrack->GetId();
    clip.key.clipId = au3clip->GetId();
    clip.title = wxToString(au3clip->GetName());
    clip.startTime = au3clip->GetPlayStartTime();
    clip.endTime = au3clip->GetPlayEndTime();
    clip.color = muse::draw::Color::fromString(waveTrack->GetColor());
    clip.stereo = au3clip->NChannels() > 1;

    clip.pitch = au3clip->GetCentShift();
    clip.speed = au3clip->GetStretchRatio();
    clip.optimizeForVoice = au3clip->GetPitchAndSpeedPreset() == PitchAndSpeedPreset::OptimizeForVoice;

    clip.stretchToMatchTempo = au3clip->GetStretchToMatchProjectTempo();

    return clip;
}

au::trackedit::Track DomConverter::track(const Au3Track* waveTrack)
{
    trackedit::Track au4t;
    au4t.id = waveTrack->GetId();
    au4t.title = wxToString(waveTrack->GetName());
    au4t.type = trackType(waveTrack);
    au4t.color = muse::draw::Color::fromString(waveTrack->GetColor());

    return au4t;
}
