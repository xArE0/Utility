package com.example.utility

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.provider.Settings

/**
 * Keeps the widget's stay-awake button in step with the screen-off timeout when it is changed
 * outside the widget (system Settings, another app). A content-URI trigger: the system watches
 * the setting and only starts this when it changes — no polling, no service kept alive. Such jobs
 * fire once and can't be persisted, so it re-arms itself on every run and [UtilityWidget.restore]
 * arms it after boot, app update and app start.
 */
class SettingsWatchJob : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        schedule(applicationContext)
        UtilityWidget.changed(applicationContext)
        return false
    }

    override fun onStopJob(params: JobParameters) = false

    companion object {
        private const val JOB_ID = 7420

        fun schedule(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
            val uri = Settings.System.getUriFor(Settings.System.SCREEN_OFF_TIMEOUT)
            val job = JobInfo.Builder(JOB_ID, ComponentName(context, SettingsWatchJob::class.java))
                .addTriggerContentUri(JobInfo.TriggerContentUri(uri, 0))
                .setTriggerContentUpdateDelay(0)
                .setTriggerContentMaxDelay(0)
                .build()
            context.getSystemService(JobScheduler::class.java).schedule(job)
        }
    }
}
